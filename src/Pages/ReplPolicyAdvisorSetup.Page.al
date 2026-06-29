/// <summary>
/// Administration card for the Replenishment Policy Advisor Setup singleton: edit the
/// demand-history window, the demand-classification thresholds (ADI and CV-squared), and
/// the behaviour switches (shelf-life steers to Maximum Qty., auto-update of the item
/// reordering policy, make-to-order skip, logging), and open the advice log.
/// </summary>
page 50400 "Repl. Policy Advisor Setup"
{
    Caption = 'Replenishment Policy Advisor Setup';
    PageType = Card;
    SourceTable = "Repl. Policy Advisor Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Inputs)
            {
                Caption = 'Demand Classification';

                field("History Window (Days)"; Rec."History Window (Days)")
                {
                    ApplicationArea = All;
                    ToolTip = 'How many days of posted sales history (backwards from today) to use when classifying the demand pattern. 365 days smooths seasonality into a steady picture.';
                }
                field("Min Demand Observations"; Rec."Min Demand Observations")
                {
                    ApplicationArea = All;
                    ToolTip = 'Minimum number of days with demand needed to classify the item. Below this, the advisor returns Insufficient Data instead of guessing a policy.';
                }
                field("Lumpy ADI Threshold"; Rec."Lumpy ADI Threshold")
                {
                    ApplicationArea = All;
                    ToolTip = 'Average Demand Interval threshold. ADI is the mean number of calendar days between days that had demand. At or above this value demand is treated as infrequent (Intermittent or Lumpy) and steered to Lot-for-Lot. The textbook default is 1.32.';
                }
                field("Erratic CV2 Threshold"; Rec."Erratic CV2 Threshold")
                {
                    ApplicationArea = All;
                    ToolTip = 'Squared coefficient of variation threshold for the demand size. At or above this value the order sizes are treated as erratic. Used together with ADI to label the pattern Smooth / Erratic / Intermittent / Lumpy. The textbook default is 0.49.';
                }
            }
            group(Behaviour)
            {
                Caption = 'Behaviour';

                field("Perishable Means Max Qty."; Rec."Perishable Means Max Qty.")
                {
                    ApplicationArea = All;
                    ToolTip = 'When an item with frequent demand has a Shelf Life set, recommend Maximum Qty. so replenishment refills up to a ceiling and caps standing stock, rather than Fixed Reorder Qty.';
                }
                field("Auto-Update Reordering Policy"; Rec."Auto-Update Reordering Policy")
                {
                    ApplicationArea = All;
                    ToolTip = 'Write the recommended Reordering Policy back to the item. Off by default: a reordering policy change is consequential, so the advisor is advisory unless you opt in. Make-to-order items are never auto-flipped.';
                }
                field("Skip Make-to-Order"; Rec."Skip Make-to-Order")
                {
                    ApplicationArea = All;
                    ToolTip = 'Recommend Order for items with Manufacturing Policy = Make-to-Order or Reordering Policy = Order, and do not write a make-to-stock policy over them. These are pegged to demand.';
                }
                field("Log History"; Rec."Log History")
                {
                    ApplicationArea = All;
                    ToolTip = 'Save each advice run to a history log for traceability and audit.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenLog)
            {
                Caption = 'Advice Log';
                ApplicationArea = All;
                Image = Log;
                RunObject = page "Repl. Policy Advice Log";
                ToolTip = 'Open the Replenishment Policy Advice Log to review past advice runs (all items, all users).';
            }
        }
        area(Promoted)
        {
            actionref(OpenLog_Promoted; OpenLog)
            {
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetSetup();
    end;
}
