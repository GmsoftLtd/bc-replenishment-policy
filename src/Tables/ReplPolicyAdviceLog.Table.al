/// <summary>
/// History log of Replenishment Policy Advisor runs. One entry per advised item per run,
/// capturing the three planning numbers (safety stock, reorder point, order quantity/EOQ)
/// as they stood on the item, the demand statistics used to classify the item (average
/// daily demand, observations, Average Demand Interval, squared coefficient of variation,
/// demand pattern), the current and recommended reordering policy, whether the
/// recommendation was applied, and an explanatory note.
/// </summary>
table 50401 "Repl. Policy Advice Log"
{
    Caption = 'Replenishment Policy Advice Log';
    DataClassification = CustomerContent;
    LookupPageId = "Repl. Policy Advice Log";
    DrillDownPageId = "Repl. Policy Advice Log";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = SystemMetadata;
        }
        field(2; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item;
        }
        field(3; "Advice DateTime"; DateTime)
        {
            Caption = 'Advice DateTime';
            DataClassification = CustomerContent;
        }
        field(4; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
        }
        field(10; "Avg Daily Demand"; Decimal)
        {
            Caption = 'Avg Daily Demand';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 5;
        }
        field(11; "Demand Observations"; Integer)
        {
            Caption = 'Demand Observations';
            DataClassification = CustomerContent;
        }
        field(12; "Avg Demand Interval (ADI)"; Decimal)
        {
            Caption = 'Avg Demand Interval (ADI)';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(13; "Demand CV Squared"; Decimal)
        {
            Caption = 'Demand CV Squared';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(14; "Demand Pattern"; Text[30])
        {
            Caption = 'Demand Pattern';
            DataClassification = CustomerContent;
        }
        field(15; "Replenishment System"; Text[30])
        {
            Caption = 'Replenishment System';
            DataClassification = CustomerContent;
        }
        field(20; "Safety Stock"; Decimal)
        {
            Caption = 'Safety Stock';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(21; "Reorder Point"; Decimal)
        {
            Caption = 'Reorder Point';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(22; "Order Quantity (EOQ)"; Decimal)
        {
            Caption = 'Order Quantity (EOQ)';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(23; "Maximum Inventory"; Decimal)
        {
            Caption = 'Maximum Inventory';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(24; "Unit Cost"; Decimal)
        {
            Caption = 'Unit Cost';
            DataClassification = CustomerContent;
            AutoFormatType = 2;
        }
        field(30; "Current Policy"; Text[30])
        {
            Caption = 'Current Reordering Policy';
            DataClassification = CustomerContent;
        }
        field(31; "Recommended Policy"; Enum "Repl. Policy Recommendation")
        {
            Caption = 'Recommended Policy';
            DataClassification = CustomerContent;
        }
        field(32; Applied; Boolean)
        {
            Caption = 'Applied';
            DataClassification = CustomerContent;
        }
        field(40; Note; Text[250])
        {
            Caption = 'Note';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(Item; "Item No.", "Advice DateTime") { }
    }
}
