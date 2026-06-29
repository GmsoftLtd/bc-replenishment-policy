/// <summary>
/// Core engine for the Replenishment Policy Advisor. For a make-to-stock item it reads
/// the three planning numbers already on the Item card (safety stock, reorder point,
/// order quantity / EOQ), classifies the item's demand pattern from posted sales, and
/// recommends one of Fixed Reorder Qty., Maximum Qty., Lot-for-Lot — or Order, for a
/// make-to-order item whose supply is pegged to demand. It can optionally write the
/// recommended Reordering Policy back to the item, and records each run in the advice log.
///
/// The recommendation is deterministic. It does not invent the three numbers — those come
/// from the companion calculators (bc-safety-stock, bc-eoq-calculator, bc-reorder-point)
/// or from whatever is on the item already. It decides which policy should consume them.
/// </summary>
codeunit 50400 "Replenishment Policy Advisor"
{
    Permissions = tabledata Item = rm,
                  tabledata "Repl. Policy Advice Log" = ri;

    var
        Setup: Record "Repl. Policy Advisor Setup";
        SetupLoaded: Boolean;

    /// <summary>
    /// Advises a reordering policy for a single item and (optionally) writes it back.
    /// The computed numbers, demand statistics, pattern and note are returned in the
    /// temporary Advice record so the caller can present them.
    /// </summary>
    /// <param name="ItemNo">The item to advise.</param>
    /// <param name="Apply">When true, writes the recommended Reordering Policy to the item (subject to setup) and logs it as applied.</param>
    /// <param name="Advice">Out: a temporary record carrying the three numbers, demand statistics, recommendation and note.</param>
    /// <returns>The recommended policy, or Insufficient Data when the item cannot be classified.</returns>
    procedure AdviseForItem(ItemNo: Code[20]; Apply: Boolean; var Advice: Record "Repl. Policy Advice Log"): Enum "Repl. Policy Recommendation"
    begin
        exit(RunAdvice(ItemNo, Apply, true, Advice));
    end;

    /// <summary>
    /// Advises a reordering policy for a single item WITHOUT applying it and WITHOUT writing
    /// a log entry. Use for an interactive preview before the user confirms, so a cancelled
    /// preview never leaves a row in the advice log.
    /// </summary>
    /// <param name="ItemNo">The item to advise.</param>
    /// <param name="Advice">Out: a temporary record carrying the three numbers, demand statistics, recommendation and note.</param>
    /// <returns>The recommended policy, or Insufficient Data when the item cannot be classified.</returns>
    procedure AdvisePreview(ItemNo: Code[20]; var Advice: Record "Repl. Policy Advice Log"): Enum "Repl. Policy Recommendation"
    begin
        exit(RunAdvice(ItemNo, false, false, Advice));
    end;

    local procedure RunAdvice(ItemNo: Code[20]; Apply: Boolean; DoLog: Boolean; var Advice: Record "Repl. Policy Advice Log"): Enum "Repl. Policy Recommendation"
    var
        Item: Record Item;
        Recommendation: Enum "Repl. Policy Recommendation";
        AvgDemand: Decimal;
        Observations: Integer;
        ADI: Decimal;
        CV2: Decimal;
        Pattern: Text[30];
        Note: Text[250];
        Applied: Boolean;
    begin
        EnsureSetup();

        Advice.Reset();
        Advice.DeleteAll();
        Advice.Init();
        Advice."Entry No." := 0;
        Advice."Item No." := CopyStr(ItemNo, 1, MaxStrLen(Advice."Item No."));
        Advice."Advice DateTime" := CurrentDateTime;

        if not Item.Get(ItemNo) then begin
            Recommendation := Recommendation::"Insufficient Data";
            Finalize(Advice, Recommendation, 'Item not found.', false, DoLog);
            exit(Recommendation);
        end;

        // Snapshot the three numbers and context that already live on the item.
        Advice."Safety Stock" := Item."Safety Stock Quantity";
        Advice."Reorder Point" := Item."Reorder Point";
        Advice."Order Quantity (EOQ)" := Item."Reorder Quantity";
        Advice."Maximum Inventory" := Item."Maximum Inventory";
        Advice."Unit Cost" := Item."Unit Cost";
        Advice."Current Policy" := CopyStr(Format(Item."Reordering Policy"), 1, MaxStrLen(Advice."Current Policy"));
        Advice."Replenishment System" := CopyStr(Format(Item."Replenishment System"), 1, MaxStrLen(Advice."Replenishment System"));

        if Item.Type <> Item.Type::Inventory then begin
            Recommendation := Recommendation::"Insufficient Data";
            Finalize(Advice, Recommendation, 'Not an inventory item: a reordering policy does not apply.', false, DoLog);
            exit(Recommendation);
        end;

        if Item.Blocked then begin
            Recommendation := Recommendation::"Insufficient Data";
            Finalize(Advice, Recommendation, 'Item is blocked.', false, DoLog);
            exit(Recommendation);
        end;

        if Setup."Skip Make-to-Order" and IsMakeToOrder(Item) then begin
            Recommendation := Recommendation::Order;
            Finalize(Advice, Recommendation,
                'Make-to-order: keep Reordering Policy = Order so each supply pegs to one demand. Safety stock, reorder point and EOQ do not apply to this item. Its purchased/produced components are make-to-stock, however, and should be advised individually.',
                false, DoLog);
            exit(Recommendation);
        end;

        ComputeDemandStats(ItemNo, AvgDemand, Observations, ADI, CV2);
        Advice."Avg Daily Demand" := AvgDemand;
        Advice."Demand Observations" := Observations;
        Advice."Avg Demand Interval (ADI)" := ADI;
        Advice."Demand CV Squared" := CV2;

        if Observations < Setup."Min Demand Observations" then begin
            Recommendation := Recommendation::"Insufficient Data";
            Advice."Demand Pattern" := 'Unknown';
            Finalize(Advice, Recommendation,
                StrSubstNo('Only %1 day(s) with demand (minimum %2). Not enough sales history to classify the demand pattern.', Observations, Setup."Min Demand Observations"),
                false, DoLog);
            exit(Recommendation);
        end;

        Pattern := ClassifyPattern(ADI, CV2);
        Advice."Demand Pattern" := Pattern;

        Recommendation := Recommend(Item, ADI, Pattern, Note);

        // Apply only the three make-to-stock policies; never auto-flip a stocked item to Order.
        if Apply and Setup."Auto-Update Reordering Policy" and IsApplicablePolicy(Recommendation) then begin
            case Recommendation of
                Recommendation::"Fixed Reorder Qty.":
                    Item.Validate("Reordering Policy", Item."Reordering Policy"::"Fixed Reorder Qty.");
                Recommendation::"Maximum Qty.":
                    Item.Validate("Reordering Policy", Item."Reordering Policy"::"Maximum Qty.");
                Recommendation::"Lot-for-Lot":
                    Item.Validate("Reordering Policy", Item."Reordering Policy"::"Lot-for-Lot");
            end;
            Item.Modify(true);
            Applied := true;
        end;

        Finalize(Advice, Recommendation,
            CopyStr(Note + ' ' + NumbersLine(Advice), 1, MaxStrLen(Advice.Note)),
            Applied, DoLog);
        exit(Recommendation);
    end;

    /// <summary>
    /// Bulk advice for the items currently filtered on the Item record passed in. Each item
    /// is advised and logged; make-to-order items are recommended Order (and skipped from any
    /// policy write), so the run is honest about coverage.
    /// </summary>
    /// <param name="ItemFilter">The item record whose current filters define the set to process.</param>
    /// <param name="Apply">When true, writes each recommended policy to the item (subject to setup) and logs it as applied.</param>
    /// <returns>The number of items processed.</returns>
    procedure AdviseBulk(var ItemFilter: Record Item; Apply: Boolean): Integer
    var
        Item: Record Item;
        Advice: Record "Repl. Policy Advice Log" temporary;
        ProcessedCount: Integer;
        Window: Dialog;
        Total: Integer;
        Done: Integer;
    begin
        EnsureSetup();

        Item.CopyFilters(ItemFilter);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        Total := Item.Count();
        if Total = 0 then
            exit(0);

        if GuiAllowed then begin
            Window.Open('Advising replenishment policy...\#1######### / #2#########');
            Window.Update(2, Format(Total));
        end;

        if Item.FindSet() then
            repeat
                Done += 1;
                if GuiAllowed then
                    Window.Update(1, Format(Done));
                AdviseForItem(Item."No.", Apply, Advice);
                ProcessedCount += 1;
            until Item.Next() = 0;

        if GuiAllowed then
            Window.Close();
        exit(ProcessedCount);
    end;

    /// <summary>
    /// Single source of truth for "is this item make-to-order". Two signals point at the
    /// same thing: supply is pegged to a single demand, so there is no replenished stock
    /// level for a reorder point to defend.
    /// </summary>
    /// <param name="Item">The item to classify.</param>
    /// <returns>True if the item is make-to-order (Make-to-Order manufacturing policy or Order reordering policy).</returns>
    procedure IsMakeToOrder(Item: Record Item): Boolean
    begin
        if Item."Manufacturing Policy" = Item."Manufacturing Policy"::"Make-to-Order" then
            exit(true);
        if Item."Reordering Policy" = Item."Reordering Policy"::Order then
            exit(true);
        exit(false);
    end;

    local procedure EnsureSetup()
    begin
        if not SetupLoaded then begin
            Setup.GetSetup();
            SetupLoaded := true;
        end;
    end;

    /// <summary>
    /// Classifies daily sales demand using the Syntetos-Boylan-Croston scheme: the Average
    /// Demand Interval (ADI, mean number of calendar days between days with demand) against
    /// the squared coefficient of variation (CV2) of the demand sizes. Smooth, Erratic,
    /// Intermittent or Lumpy. The thresholds come from setup (defaults 1.32 / 0.49).
    /// </summary>
    local procedure ClassifyPattern(ADI: Decimal; CV2: Decimal): Text[30]
    begin
        if ADI < Setup."Lumpy ADI Threshold" then begin
            if CV2 < Setup."Erratic CV2 Threshold" then
                exit('Smooth');
            exit('Erratic');
        end;
        if CV2 < Setup."Erratic CV2 Threshold" then
            exit('Intermittent');
        exit('Lumpy');
    end;

    /// <summary>
    /// The decision tree. Infrequent demand (ADI at/above the threshold: Intermittent or
    /// Lumpy) goes to Lot-for-Lot, which orders to each demand and holds no standing stock.
    /// Frequent demand goes to a reorder-point policy: Maximum Qty. when there is a reason
    /// to cap inventory (a shelf life, or a Maximum Inventory already set), otherwise Fixed
    /// Reorder Qty., which orders a fixed economic quantity each time stock crosses the
    /// reorder point.
    /// </summary>
    local procedure Recommend(Item: Record Item; ADI: Decimal; Pattern: Text[30]; var Note: Text[250]): Enum "Repl. Policy Recommendation"
    var
        Recommendation: Enum "Repl. Policy Recommendation";
    begin
        if ADI >= Setup."Lumpy ADI Threshold" then begin
            Note := StrSubstNo('%1 demand: stock turns over infrequently (ADI %2 >= %3). Lot-for-Lot orders to each demand and holds no standing stock, so there is no reorder point to defend. Keep safety stock only on the few lines a stockout would actually hurt.',
                Pattern, Format(Round(ADI, 0.01), 0, 9), Format(Setup."Lumpy ADI Threshold", 0, 9));
            exit(Recommendation::"Lot-for-Lot");
        end;

        if Setup."Perishable Means Max Qty." and HasShelfLife(Item) then begin
            Note := StrSubstNo('%1 demand with a shelf life set. Maximum Qty. refills up to a ceiling (Maximum Inventory) when stock crosses the reorder point, capping standing stock so nothing expires. Set both Reorder Point and Maximum Inventory; the order quantity varies up to the cap.', Pattern);
            exit(Recommendation::"Maximum Qty.");
        end;

        if Item."Maximum Inventory" > 0 then begin
            Note := StrSubstNo('%1 demand with a Maximum Inventory cap already set. Maximum Qty. refills up to that ceiling when stock crosses the reorder point.', Pattern);
            exit(Recommendation::"Maximum Qty.");
        end;

        Note := StrSubstNo('%1 demand, no inventory cap. Fixed Reorder Qty. orders a fixed economic quantity (EOQ) each time stock crosses the reorder point — the classic make-to-stock buy. Set Reorder Point and Reorder Quantity (EOQ).', Pattern);
        exit(Recommendation::"Fixed Reorder Qty.");
    end;

    /// <summary>
    /// Reads Item Ledger Entries of type Sale over the history window and derives the
    /// statistics used to classify demand: average daily demand (over all calendar days),
    /// the number of days with demand (observations), the Average Demand Interval, and the
    /// squared coefficient of variation of the per-day demand sizes.
    /// </summary>
    local procedure ComputeDemandStats(ItemNo: Code[20]; var AvgDemand: Decimal; var Observations: Integer; var ADI: Decimal; var CV2: Decimal)
    var
        ILE: Record "Item Ledger Entry";
        DailyDemand: Dictionary of [Date, Decimal];
        WindowStart: Date;
        CalendarDays: Integer;
        SellingDays: Integer;
        SumQty: Decimal;
        MeanSize: Decimal;
        SumSqDiff: Decimal;
        Variance: Decimal;
        qty: Decimal;
        d: Date;
    begin
        AvgDemand := 0;
        Observations := 0;
        ADI := 0;
        CV2 := 0;

        WindowStart := CalcDate(StrSubstNo('<-%1D>', Setup."History Window (Days)"), Today);
        CalendarDays := Today - WindowStart + 1;
        if CalendarDays <= 0 then
            exit;

        ILE.SetCurrentKey("Item No.", "Posting Date");
        ILE.SetRange("Item No.", ItemNo);
        ILE.SetRange("Posting Date", WindowStart, Today);
        ILE.SetRange("Entry Type", ILE."Entry Type"::Sale);
        if not ILE.FindSet() then
            exit;

        // Sales post as a negative quantity on the Item Ledger Entry; flip to positive demand.
        repeat
            qty := -ILE.Quantity;
            if qty > 0 then begin
                if DailyDemand.ContainsKey(ILE."Posting Date") then
                    DailyDemand.Set(ILE."Posting Date", DailyDemand.Get(ILE."Posting Date") + qty)
                else
                    DailyDemand.Add(ILE."Posting Date", qty);
            end;
        until ILE.Next() = 0;

        SellingDays := DailyDemand.Count;
        if SellingDays = 0 then
            exit;

        foreach d in DailyDemand.Keys do
            SumQty += DailyDemand.Get(d);

        Observations := SellingDays;
        AvgDemand := SumQty / CalendarDays;

        // ADI: mean number of calendar days between days that actually had demand.
        ADI := CalendarDays / SellingDays;

        // CV2: squared coefficient of variation of the per-day demand SIZES (not the
        // calendar-spread average), measuring how erratic an order size is when it occurs.
        MeanSize := SumQty / SellingDays;
        if MeanSize > 0 then begin
            foreach d in DailyDemand.Keys do
                SumSqDiff += Power(DailyDemand.Get(d) - MeanSize, 2);
            Variance := SumSqDiff / SellingDays;
            CV2 := Variance / Power(MeanSize, 2);
        end;
    end;

    local procedure HasShelfLife(Item: Record Item): Boolean
    begin
        exit(Format(Item."Shelf Life") <> '');
    end;

    local procedure IsApplicablePolicy(Recommendation: Enum "Repl. Policy Recommendation"): Boolean
    begin
        exit(Recommendation in [
            Recommendation::"Fixed Reorder Qty.",
            Recommendation::"Maximum Qty.",
            Recommendation::"Lot-for-Lot"]);
    end;

    local procedure NumbersLine(var Advice: Record "Repl. Policy Advice Log"): Text
    begin
        exit(StrSubstNo('[SS=%1, ROP=%2, EOQ=%3]',
            Format(Advice."Safety Stock", 0, 9),
            Format(Advice."Reorder Point", 0, 9),
            Format(Advice."Order Quantity (EOQ)", 0, 9)));
    end;

    local procedure Finalize(var Advice: Record "Repl. Policy Advice Log"; Recommendation: Enum "Repl. Policy Recommendation"; Note: Text[250]; Applied: Boolean; DoLog: Boolean)
    begin
        Advice."Recommended Policy" := Recommendation;
        Advice.Note := Note;
        Advice.Applied := Applied;
        // Keep the carrier addressable as a single temporary row for the caller.
        if not Advice.Insert() then
            Advice.Modify();
        if DoLog then
            LogAdvice(Advice);
    end;

    local procedure LogAdvice(var Advice: Record "Repl. Policy Advice Log")
    var
        LogEntry: Record "Repl. Policy Advice Log";
    begin
        EnsureSetup();
        if not Setup."Log History" then
            exit;
        LogEntry.Init();
        LogEntry.TransferFields(Advice, false); // false: do not copy the AutoIncrement primary key
        LogEntry."User ID" := CopyStr(UserId, 1, MaxStrLen(LogEntry."User ID"));
        LogEntry.Insert(true);
    end;
}
