/// <summary>
/// Read-only list of Replenishment Policy Advice Log entries, newest first, showing the
/// three planning numbers, the demand statistics and pattern, and the current versus
/// recommended reordering policy for each advised item, for traceability and audit.
/// </summary>
page 50401 "Repl. Policy Advice Log"
{
    Caption = 'Replenishment Policy Advice Log';
    PageType = List;
    SourceTable = "Repl. Policy Advice Log";
    UsageCategory = History;
    ApplicationArea = All;
    Editable = false;
    SourceTableView = sorting("Entry No.") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Advice DateTime"; Rec."Advice DateTime") { ApplicationArea = All; }
                field("Item No."; Rec."Item No.") { ApplicationArea = All; }
                field("Recommended Policy"; Rec."Recommended Policy") { ApplicationArea = All; }
                field("Current Policy"; Rec."Current Policy") { ApplicationArea = All; }
                field("Applied"; Rec."Applied") { ApplicationArea = All; }
                field("Demand Pattern"; Rec."Demand Pattern") { ApplicationArea = All; }
                field("Avg Daily Demand"; Rec."Avg Daily Demand") { ApplicationArea = All; }
                field("Avg Demand Interval (ADI)"; Rec."Avg Demand Interval (ADI)") { ApplicationArea = All; }
                field("Demand CV Squared"; Rec."Demand CV Squared") { ApplicationArea = All; }
                field("Demand Observations"; Rec."Demand Observations") { ApplicationArea = All; }
                field("Safety Stock"; Rec."Safety Stock") { ApplicationArea = All; }
                field("Reorder Point"; Rec."Reorder Point") { ApplicationArea = All; }
                field("Order Quantity (EOQ)"; Rec."Order Quantity (EOQ)") { ApplicationArea = All; }
                field("Maximum Inventory"; Rec."Maximum Inventory") { ApplicationArea = All; }
                field("Unit Cost"; Rec."Unit Cost") { ApplicationArea = All; }
                field("Replenishment System"; Rec."Replenishment System") { ApplicationArea = All; }
                field("User ID"; Rec."User ID") { ApplicationArea = All; }
                field(Note; Rec.Note) { ApplicationArea = All; }
            }
        }
    }
}
