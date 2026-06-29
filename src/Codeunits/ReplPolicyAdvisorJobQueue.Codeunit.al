/// <summary>
/// Job Queue entry point for unattended replenishment-policy advice. Schedule as Codeunit
/// 50401; an optional Parameter String of the form "FILTER=FieldName:Value" narrows the
/// item set. Without parameters, all inventory items are advised (make-to-order items are
/// recommended Order and skipped from any policy write). Whether the recommended policy is
/// written back is governed by the Auto-Update setting on the advisor setup card.
/// </summary>
codeunit 50401 "Repl. Policy Advisor Job"
{
    // Schedule via: Job Queue Entry -> Object Type to Run: Codeunit -> Object ID: 50401
    // The Job Queue Entry record can carry a Parameter String like "FILTER=Item Category Code:FERT".
    // Without parameters, all inventory items are advised.

    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        Item: Record Item;
        Advisor: Codeunit "Replenishment Policy Advisor";
        Params: Text;
        FilterClause: Text;
    begin
        Params := Rec."Parameter String";
        FilterClause := GetParam(Params, 'FILTER');

        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);

        if FilterClause <> '' then
            ApplySimpleFilter(Item, FilterClause);

        // Apply = true: the policy write is still gated by Auto-Update Reordering Policy in setup.
        Advisor.AdviseBulk(Item, true);
    end;

    local procedure GetParam(Params: Text; pKey: Text): Text
    var
        Segments: List of [Text];
        Segment: Text;
        KvSplit: Integer;
        ThisKey: Text;
    begin
        Segments := Params.Split(';');
        foreach Segment in Segments do begin
            KvSplit := StrPos(Segment, '=');
            if KvSplit > 0 then begin
                ThisKey := CopyStr(Segment, 1, KvSplit - 1).Trim();
                if UpperCase(ThisKey) = UpperCase(pKey) then
                    exit(CopyStr(Segment, KvSplit + 1).Trim());
            end;
        end;
        exit('');
    end;

    local procedure ApplySimpleFilter(var Item: Record Item; Clause: Text)
    var
        ColonIdx: Integer;
        FieldName: Text;
        FieldValue: Text;
        BadFormatErr: Label 'Invalid FILTER parameter "%1". Expected "FieldName:Value", e.g. "FILTER=Item Category Code:FERT".', Comment = '%1 = the supplied clause';
        UnknownFieldErr: Label 'Unknown FILTER field "%1". Supported fields: Item Category Code, Inventory Posting Group, Vendor No., No.', Comment = '%1 = the supplied field name';
    begin
        // Format expected: "FieldName:Value" (e.g. "Item Category Code:FERT").
        // A malformed or unknown filter must FAIL the job, never silently fall through
        // to processing the entire item catalog.
        ColonIdx := StrPos(Clause, ':');
        if ColonIdx = 0 then
            Error(BadFormatErr, Clause);
        FieldName := CopyStr(Clause, 1, ColonIdx - 1).Trim();
        FieldValue := CopyStr(Clause, ColonIdx + 1).Trim();
        if (FieldName = '') or (FieldValue = '') then
            Error(BadFormatErr, Clause);

        case UpperCase(FieldName) of
            'ITEM CATEGORY CODE', 'ITEMCATEGORY':
                Item.SetFilter("Item Category Code", FieldValue);
            'INVENTORY POSTING GROUP', 'POSTINGGROUP':
                Item.SetFilter("Inventory Posting Group", FieldValue);
            'VENDOR NO.', 'VENDORNO':
                Item.SetFilter("Vendor No.", FieldValue);
            'NO.', 'ITEMNO':
                Item.SetFilter("No.", FieldValue);
            else
                Error(UnknownFieldErr, FieldName);
        end;
    end;
}
