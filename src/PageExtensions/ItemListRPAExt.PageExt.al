/// <summary>
/// Extends the Item List with a bulk Replenishment Policy action that advises (and, when
/// auto-update is enabled, applies) a reordering policy for the currently filtered or
/// selected items. Each item's advice is written to the log.
/// </summary>
pageextension 50401 "Item List RPA Ext" extends "Item List"
{
    actions
    {
        addlast(Promoted)
        {
            actionref(AdvisePolicyBulk_Promoted; AdvisePolicyBulk)
            {
            }
        }
        addafter("Stockkeepin&g Units")
        {
            action(AdvisePolicyBulk)
            {
                Caption = 'Advise Replenishment Policy (Bulk)';
                ApplicationArea = All;
                Image = Suggest;
                ToolTip = 'Advise a reordering policy for the items currently filtered or selected, and write each result to the advice log. Whether the recommended policy is applied to the item is governed by the Auto-Update Reordering Policy setting. Make-to-order items are recommended Order and never auto-flipped.';

                trigger OnAction()
                var
                    Item: Record Item;
                    Setup: Record "Repl. Policy Advisor Setup";
                    Advisor: Codeunit "Replenishment Policy Advisor";
                    Processed: Integer;
                    ConfirmApplyTxt: Label 'Advise a reordering policy for items matching the current filters AND write the recommended policy to each item (Auto-Update is on)?';
                    ConfirmAdviseTxt: Label 'Advise a reordering policy for items matching the current filters and log the result? (Auto-Update is off, so the items themselves are not changed.)';
                    Confirmed: Boolean;
                begin
                    CurrPage.SetSelectionFilter(Item);
                    if Item.GetFilter("No.") = '' then
                        Item.CopyFilters(Rec);

                    Setup.GetSetup();
                    if Setup."Auto-Update Reordering Policy" then
                        Confirmed := Confirm(ConfirmApplyTxt, false)
                    else
                        Confirmed := Confirm(ConfirmAdviseTxt, false);
                    if not Confirmed then
                        exit;

                    Processed := Advisor.AdviseBulk(Item, true);
                    Message('Advised %1 item(s). See the Replenishment Policy Advice Log for the recommendation and reason for each.', Processed);
                end;
            }
        }
    }
}
