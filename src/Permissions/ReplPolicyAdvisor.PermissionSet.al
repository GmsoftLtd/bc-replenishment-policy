/// <summary>
/// Assignable permission set granting full access to all Replenishment Policy Advisor
/// objects: the setup and advice log tables (with data) and the advisor, job queue
/// codeunits and pages.
/// </summary>
permissionset 50400 "Repl. Policy Advisor"
{
    Assignable = true;
    Caption = 'Replenishment Policy Advisor - All';

    Permissions = tabledata "Repl. Policy Advisor Setup" = RIMD,
                  tabledata "Repl. Policy Advice Log" = RIMD,
                  table "Repl. Policy Advisor Setup" = X,
                  table "Repl. Policy Advice Log" = X,
                  codeunit "Replenishment Policy Advisor" = X,
                  codeunit "Repl. Policy Advisor Job" = X,
                  page "Repl. Policy Advisor Setup" = X,
                  page "Repl. Policy Advice Log" = X;
}
