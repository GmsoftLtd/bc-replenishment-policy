/// <summary>
/// The reordering policy the advisor recommends for a make-to-stock item, or the
/// reason it could not recommend one. The four real values map directly to the BC
/// Item "Reordering Policy" options the planning engine reads; "Insufficient Data"
/// means there was not enough demand history to classify the item. Extensible.
/// </summary>
enum 50400 "Repl. Policy Recommendation"
{
    Extensible = true;

    value(0; "Insufficient Data")
    {
        Caption = 'Insufficient Data';
    }
    value(1; Order)
    {
        Caption = 'Order (Make-to-Order)';
    }
    value(2; "Lot-for-Lot")
    {
        Caption = 'Lot-for-Lot';
    }
    value(3; "Fixed Reorder Qty.")
    {
        Caption = 'Fixed Reorder Qty.';
    }
    value(4; "Maximum Qty.")
    {
        Caption = 'Maximum Qty.';
    }
}
