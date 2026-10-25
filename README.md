# BC Replenishment Policy Advisor

**Now part of the free Inventory Planning app for Business Central:** https://gmsoftdynamics.com/apps/free/inventory-planning/ | **All GMSOFT apps:** https://gmsoftdynamics.com/apps/compare/

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Business Central](https://img.shields.io/badge/BC-v27+-blue.svg)](https://learn.microsoft.com/en-us/dynamics365/business-central/)

A free, MIT-licensed Business Central extension that does the one job the other three calculators don't: it tells you **which reordering policy** should consume the numbers — Fixed Reorder Qty., Maximum Qty., Lot-for-Lot, or Order for make-to-order — by classifying each item's demand pattern from its own posted sales, with safety stock, EOQ and reorder point all in view on the same screen.

**Companion walkthrough:** [Choosing a Reordering Policy in Business Central — Fixed Reorder Qty., Maximum Qty., and Lot-for-Lot, with all three numbers in play](ARTICLE.md)

This is the capstone of a four-part replenishment set. The first three compute the numbers; this one decides the policy that reads them:

- [bc-safety-stock](https://github.com/GmsoftLtd/bc-safety-stock) — how much buffer to hold (50100-50199)
- [bc-eoq-calculator](https://github.com/GmsoftLtd/bc-eoq-calculator) — how much to order (50200-50299)
- [bc-reorder-point](https://github.com/GmsoftLtd/bc-reorder-point) — when to order (50300-50399)
- **bc-replenishment-policy** — which policy ties them together (50400-50499)

---

## The problem this solves

The three calculators each write a defensible number into a standard BC field:

| Number | Field the planning engine reads | Set by |
|---|---|---|
| Safety Stock | `Item."Safety Stock Quantity"` | bc-safety-stock |
| Reorder Point | `Item."Reorder Point"` | bc-reorder-point |
| Order Quantity (EOQ) | `Item."Reorder Quantity"` | bc-eoq-calculator |

But a number only does anything if the **Reordering Policy** is set to a policy that uses it. A perfect reorder point on an item left at `Lot-for-Lot` is ignored; a perfect EOQ on an item set to `Maximum Qty.` is overridden by the maximum. The policy is the gate.

This extension reads the three numbers as they stand, classifies the item's demand, and recommends the policy that matches — with a plain-English reason and the numbers next to it.

## How it decides

It classifies daily sales demand with the **Syntetos-Boylan-Croston** scheme: the Average Demand Interval (ADI — mean calendar days between days that had demand) against the squared coefficient of variation (CV²) of the demand sizes.

```
                 CV² < 0.49 (steady size)    CV² >= 0.49 (erratic size)
ADI <  1.32      Smooth                      Erratic          -> reorder-point policy
ADI >= 1.32      Intermittent                Lumpy            -> Lot-for-Lot
```

Then:

1. **Make-to-order** (Manufacturing Policy = Make-to-Order, or Reordering Policy = Order) → **Order**. Supply pegs to one demand; the three numbers don't apply. (Its components are make-to-stock and get advised on their own.)
2. **Infrequent demand** (ADI ≥ threshold — Intermittent or Lumpy) → **Lot-for-Lot**. Order to each demand, hold no standing stock, no reorder point to defend.
3. **Frequent demand with a reason to cap inventory** — a Shelf Life set, or a Maximum Inventory already set → **Maximum Qty.** Refill up to a ceiling; order quantity varies.
4. **Frequent demand, no cap** → **Fixed Reorder Qty.** Order the fixed EOQ each time stock crosses the reorder point — the classic make-to-stock buy.

The recommendation is deterministic and every input is logged. Thresholds live on the setup card.

## Features

- **Item Card action** — *Advise Replenishment Policy* — shows the three numbers and the demand pattern, recommends a policy with a reason, and (if enabled) offers to apply it
- **Item List bulk action** — *Advise Replenishment Policy (Bulk)* — advise all filtered/selected items
- **Advice log** — every run logged (item, datetime, user, the three numbers, demand stats, pattern, current vs recommended policy, applied, reason)
- **Job Queue codeunit** — schedule recurring bulk advice
- **Setup page** — history window, ADI / CV² thresholds, shelf-life-means-Maximum-Qty., auto-update, make-to-order skip, logging
- **Advisory by default** — `Auto-Update Reordering Policy` is **off** out of the box: a policy change is consequential, so the extension recommends and you decide, until you opt in

## It does not invent the numbers

This extension **reads** `Safety Stock Quantity`, `Reorder Point`, `Reorder Quantity` and `Maximum Inventory` from the item — it does not compute them. Run the three calculators (or set the fields yourself) first; this one decides which policy should consume them and shows them side by side. It has **no dependency** on the other three apps: it works against the standard fields whether or not they are installed.

## Installation

### From source

1. Clone this repo
2. Open `app.json` and confirm the object ID range does not conflict (default 50400-50499)
3. In VS Code with the AL extension, run **AL: Publish** (Ctrl+F5) to your BC sandbox
4. Or build with `al package` and upload the `.app` via **Extension Management**

### From a packaged .app

Releases (when available) at the [Releases page](https://github.com/GmsoftLtd/bc-replenishment-policy/releases).

## Usage

### Single item

1. Open any Item Card
2. Click **Advise Replenishment Policy** (Actions tab)
3. Read the three numbers, the demand pattern, the recommended policy and the reason
4. If auto-update is on and the recommendation differs from the current policy, confirm to apply

### Bulk

1. Open the Item List
2. Filter to the items you want (e.g. by Item Category Code)
3. Click **Advise Replenishment Policy (Bulk)**
4. Each item is advised and logged; with auto-update off, nothing on the items changes

### Job Queue

To schedule monthly advice for all FERT items:

1. **Job Queue Entries → New**
2. Object Type to Run: **Codeunit**
3. Object ID: **50401** (Repl. Policy Advisor Job)
4. Parameter String: `FILTER=Item Category Code:FERT`
5. Set the recurring schedule

Without parameters, all inventory items are advised. Whether the recommended policy is written back is governed by **Auto-Update Reordering Policy** on the setup card.

## Configuration

**Replenishment Policy Advisor Setup** page (Search → Replenishment Policy Advisor Setup):

- **Demand History Window (Days)** — how far back to look (365 = a full year)
- **Min Demand Observations** — minimum days-with-demand needed to classify
- **Intermittent ADI Threshold** — ADI at/above this is infrequent demand → Lot-for-Lot (default 1.32)
- **Erratic CV-Squared Threshold** — CV² at/above this is erratic order sizes (default 0.49)
- **Treat Shelf Life as Maximum Qty.** — perishable, frequent-demand items go to Maximum Qty.
- **Auto-Update Item Reordering Policy** — write the recommended policy to the item (off by default)
- **Skip Make-to-Order Items** — recommend Order and never auto-flip pegged items
- **Log Advice History** — save every run

## Limitations

- **Reads, does not compute, the three numbers** — pair with bc-safety-stock, bc-eoq-calculator, bc-reorder-point (or set the fields manually)
- **Sales-based demand** — classifies from Item Ledger Entries of type `Sale`; components consumed in production (`Consumption`) are out of scope
- **Pattern, not forecast** — the ADI/CV² classification describes the demand shape; it is not a seasonal forecast
- **One policy per item** — no per-location (SKU) policy split
- **Recommends; you apply** — auto-update is off by default by design

## When NOT to rely on it

- **Items below the minimum observations** — new items have no pattern yet; use a category default
- **Strategic / regulatory stocking** — a policy driven by compliance or a supply contract is not a demand decision
- **Mid-transition items** — an item being phased in or out has a misleading recent history

## Related

- [Inside Business Central — blog](https://insidebusinesscentral.com)
- The set: [bc-safety-stock](https://github.com/GmsoftLtd/bc-safety-stock), [bc-eoq-calculator](https://github.com/GmsoftLtd/bc-eoq-calculator), [bc-reorder-point](https://github.com/GmsoftLtd/bc-reorder-point)
- Microsoft Learn: [Design details: Planning parameters](https://learn.microsoft.com/dynamics365/business-central/design-details-planning-parameters) and [Reordering policies](https://learn.microsoft.com/dynamics365/business-central/design-details-reordering-policies)

## License

MIT — see [LICENSE](LICENSE).

## Contributions

Issues and pull requests welcome, especially:

- Demand classification from consumption for component-level policy advice
- Per-location (SKU) policy recommendations
- Seasonal / trended demand profiles feeding the classification

## Author

**Grigorios Mavrogeorgis** — Director and Founder of [GMSOFT Limited](https://gmsoft.co.uk)
Microsoft Dynamics 365 Business Central Community Super User, Season 1 2026
