/// <summary>
/// Singleton setup table for the Replenishment Policy Advisor: the demand-history
/// window and the thresholds that classify an item's demand pattern (Average Demand
/// Interval and squared coefficient of variation), plus switches controlling whether
/// a shelf life steers an item to Maximum Qty., whether the recommended policy is
/// written back to the item, and whether each run is logged.
/// </summary>
table 50400 "Repl. Policy Advisor Setup"
{
    Caption = 'Replenishment Policy Advisor Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(10; "History Window (Days)"; Integer)
        {
            Caption = 'Demand History Window (Days)';
            DataClassification = CustomerContent;
            MinValue = 30;
            MaxValue = 1095;
            InitValue = 365;
        }
        field(11; "Min Demand Observations"; Integer)
        {
            Caption = 'Min Demand Observations to Classify';
            DataClassification = CustomerContent;
            MinValue = 3;
            InitValue = 20;
        }
        field(12; "Lumpy ADI Threshold"; Decimal)
        {
            Caption = 'Intermittent ADI Threshold';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
            MinValue = 1;
            InitValue = 1.32;
        }
        field(13; "Erratic CV2 Threshold"; Decimal)
        {
            Caption = 'Erratic CV-Squared Threshold';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
            MinValue = 0;
            InitValue = 0.49;
        }
        field(14; "Perishable Means Max Qty."; Boolean)
        {
            Caption = 'Treat Shelf Life as Maximum Qty.';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(15; "Auto-Update Reordering Policy"; Boolean)
        {
            Caption = 'Auto-Update Item Reordering Policy';
            DataClassification = CustomerContent;
            InitValue = false;
        }
        field(16; "Skip Make-to-Order"; Boolean)
        {
            Caption = 'Skip Make-to-Order Items';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(17; "Log History"; Boolean)
        {
            Caption = 'Log Advice History';
            DataClassification = CustomerContent;
            InitValue = true;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// Returns the singleton setup record, creating it with default values on first use.
    /// </summary>
    procedure GetSetup()
    begin
        if not Get() then begin
            Init();
            Insert();
        end;
    end;
}
