/// <summary>
/// Extends the Item Card with a Replenishment Policy action: show the three planning
/// numbers (safety stock, reorder point, order quantity / EOQ) and the demand pattern
/// together, recommend a reordering policy with a plain-English reason, and — when
/// auto-update is enabled and the recommendation differs from the current policy — offer
/// to apply it. Also opens this item's advice log.
/// </summary>
pageextension 50400 "Item Card RPA Ext" extends "Item Card"
{
    actions
    {
        addlast(Promoted)
        {
            actionref(AdvisePolicy_Promoted; AdvisePolicy)
            {
            }
        }
        addafter("Stockkeepin&g Units")
        {
            action(AdvisePolicy)
            {
                Caption = 'Advise Replenishment Policy';
                ApplicationArea = All;
                Image = Suggest;
                ToolTip = 'Show the three planning numbers (safety stock, reorder point, order quantity / EOQ) and the demand pattern for this item, and recommend a reordering policy: Fixed Reorder Qty., Maximum Qty., Lot-for-Lot, or Order for make-to-order. Demand is classified from posted sales over the history window.';

                trigger OnAction()
                var
                    Setup: Record "Repl. Policy Advisor Setup";
                    Advice: Record "Repl. Policy Advice Log" temporary;
                    Advisor: Codeunit "Replenishment Policy Advisor";
                    Recommendation: Enum "Repl. Policy Recommendation";
                    CurrentPolicy: Text;
                    MsgApplyTxt: Label 'Replenishment policy advice for %1\\Recommended: %2 (current: %3)\\Safety Stock: %4\Reorder Point: %5\Order Qty (EOQ): %6\\%7\\%8\\Apply this policy to the item?', Comment = '%1 Item No., %2 recommended policy, %3 current policy, %4 safety stock, %5 reorder point, %6 order quantity, %7 demand pattern line, %8 reason';
                    MsgInfoTxt: Label 'Replenishment policy advice for %1\\Recommended: %2 (current: %3)\\Safety Stock: %4\Reorder Point: %5\Order Qty (EOQ): %6\\%7\\%8', Comment = '%1 Item No., %2 recommended policy, %3 current policy, %4 safety stock, %5 reorder point, %6 order quantity, %7 demand pattern line, %8 reason';
                    NoneTxt: Label 'none', Comment = 'Shown when the item has no reordering policy set';
                begin
                    Setup.GetSetup();

                    // Preview only: does not write to the item or the log.
                    Recommendation := Advisor.AdvisePreview(Rec."No.", Advice);

                    CurrentPolicy := Advice."Current Policy";
                    if CurrentPolicy = '' then
                        CurrentPolicy := NoneTxt;

                    if Setup."Auto-Update Reordering Policy"
                       and (Recommendation in [Recommendation::"Fixed Reorder Qty.", Recommendation::"Maximum Qty.", Recommendation::"Lot-for-Lot"])
                       and (Format(Recommendation) <> Advice."Current Policy")
                    then begin
                        if Confirm(MsgApplyTxt, true,
                            Rec."No.", Format(Recommendation), CurrentPolicy,
                            Format(Advice."Safety Stock", 0, 9), Format(Advice."Reorder Point", 0, 9), Format(Advice."Order Quantity (EOQ)", 0, 9),
                            PatternLine(Advice), ReasonText(Advice))
                        then begin
                            Advisor.AdviseForItem(Rec."No.", true, Advice);
                            Rec.Get(Rec."No.");
                            CurrPage.Update(false);
                        end;
                    end else
                        Message(MsgInfoTxt,
                            Rec."No.", Format(Recommendation), CurrentPolicy,
                            Format(Advice."Safety Stock", 0, 9), Format(Advice."Reorder Point", 0, 9), Format(Advice."Order Quantity (EOQ)", 0, 9),
                            PatternLine(Advice), ReasonText(Advice));
                end;
            }
            action(ShowAdviceLog)
            {
                Caption = 'Replenishment Policy Advice Log';
                ApplicationArea = All;
                Image = Log;
                ToolTip = 'Show the Replenishment Policy Advice Log entries for this item.';

                trigger OnAction()
                var
                    LogEntry: Record "Repl. Policy Advice Log";
                    LogPage: Page "Repl. Policy Advice Log";
                begin
                    LogEntry.SetRange("Item No.", Rec."No.");
                    LogPage.SetTableView(LogEntry);
                    LogPage.Run();
                end;
            }
        }
    }

    local procedure PatternLine(var Advice: Record "Repl. Policy Advice Log"): Text
    var
        PatternTxt: Label 'Demand pattern: %1 (avg %2/day, %3 obs, ADI %4, CV2 %5)', Comment = '%1 pattern, %2 avg daily demand, %3 observations, %4 ADI, %5 CV squared';
        NoPatternTxt: Label 'Demand pattern: not classified', Comment = 'Shown when there is no demand history to classify';
    begin
        if Advice."Demand Pattern" = '' then
            exit(NoPatternTxt);
        exit(StrSubstNo(PatternTxt,
            Advice."Demand Pattern",
            Format(Round(Advice."Avg Daily Demand", 0.01), 0, 9),
            Format(Advice."Demand Observations"),
            Format(Round(Advice."Avg Demand Interval (ADI)", 0.01), 0, 9),
            Format(Round(Advice."Demand CV Squared", 0.01), 0, 9)));
    end;

    local procedure ReasonText(var Advice: Record "Repl. Policy Advice Log"): Text
    var
        TailPos: Integer;
    begin
        // The advisor appends a "[SS=…, ROP=…, EOQ=…]" tail to the Note for the log;
        // the dialog already shows those numbers on their own lines, so strip it here.
        TailPos := StrPos(Advice.Note, ' [SS');
        if TailPos > 0 then
            exit(CopyStr(Advice.Note, 1, TailPos - 1));
        exit(Advice.Note);
    end;
}
