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
                    Body: Text;
                    MsgApplyTxt: Label 'Replenishment policy advice for %1\\%2\\Recommended: %3 (current: %4).\\Apply this policy to the item?', Comment = '%1 Item No., %2 numbers+reason, %3 recommended policy, %4 current policy';
                    MsgInfoTxt: Label 'Replenishment policy advice for %1\\%2\\Recommended: %3 (current: %4).', Comment = '%1 Item No., %2 numbers+reason, %3 recommended policy, %4 current policy';
                begin
                    Setup.GetSetup();

                    // Preview only: does not write to the item or the log.
                    Recommendation := Advisor.AdvisePreview(Rec."No.", Advice);
                    Body := BuildBody(Advice);

                    if Setup."Auto-Update Reordering Policy"
                       and (Recommendation in [Recommendation::"Fixed Reorder Qty.", Recommendation::"Maximum Qty.", Recommendation::"Lot-for-Lot"])
                       and (Format(Recommendation) <> Advice."Current Policy")
                    then begin
                        if Confirm(MsgApplyTxt, true, Rec."No.", Body, Format(Recommendation), Advice."Current Policy") then begin
                            Advisor.AdviseForItem(Rec."No.", true, Advice);
                            Rec.Get(Rec."No.");
                            CurrPage.Update(false);
                        end;
                    end else
                        Message(MsgInfoTxt, Rec."No.", Body, Format(Recommendation), Advice."Current Policy");
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

    local procedure BuildBody(var Advice: Record "Repl. Policy Advice Log"): Text
    var
        NumbersTxt: Label 'Safety Stock: %1   Reorder Point: %2   Order Qty (EOQ): %3', Comment = '%1 safety stock, %2 reorder point, %3 order quantity';
        PatternTxt: Label 'Demand pattern: %1   (avg %2/day, %3 obs, ADI %4, CV2 %5)', Comment = '%1 pattern, %2 avg daily demand, %3 observations, %4 ADI, %5 CV squared';
    begin
        exit(
            StrSubstNo(NumbersTxt,
                Format(Advice."Safety Stock", 0, 9),
                Format(Advice."Reorder Point", 0, 9),
                Format(Advice."Order Quantity (EOQ)", 0, 9)) + '\' +
            StrSubstNo(PatternTxt,
                Advice."Demand Pattern",
                Format(Round(Advice."Avg Daily Demand", 0.01), 0, 9),
                Format(Advice."Demand Observations"),
                Format(Round(Advice."Avg Demand Interval (ADI)", 0.01), 0, 9),
                Format(Round(Advice."Demand CV Squared", 0.01), 0, 9)) + '\\' +
            Advice.Note);
    end;
}
