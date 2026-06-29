# Choosing a Reordering Policy in Business Central

### Fixed Reorder Qty., Maximum Qty., and Lot-for-Lot — with safety stock, EOQ, and the reorder point all in play on the same item

That is the trilogy done: **Safety Stock**, **EOQ**, **Reorder Point**. Three free extensions, three numbers, the full deterministic-replenishment maths for Business Central, none of them needing an AppSource subscription or a change to standard BC.

This piece pulls them together. Because three good numbers do nothing on their own — they only take effect when the item's **Reordering Policy** is set to a policy that actually reads them. A textbook reorder point on an item left at Lot-for-Lot is ignored. A carefully computed EOQ on an item set to Maximum Qty. is overridden by the maximum. The policy is the gate, and choosing it is the decision this article is about.

We'll cover what each policy does, which of the three numbers it consumes, how to choose between them, and then three worked examples on the same data model: a purchased product, a make-to-stock finished good, and a make-to-order machine with stocked components underneath. At the end, the free **bc-replenishment-policy** extension makes the recommendation for you, with the three numbers next to it.

---

## The three numbers, in one sentence each

- **Safety Stock** (`Item."Safety Stock Quantity"`) — the buffer that absorbs variability in demand and lead time so a normal wobble doesn't become a stockout. Computed by [bc-safety-stock](https://github.com/GmsoftLtd/bc-safety-stock) with the Z-score method.
- **Reorder Point** (`Item."Reorder Point"`) — the on-hand level that triggers replenishment: expected demand during the lead time, plus safety stock. Computed by [bc-reorder-point](https://github.com/GmsoftLtd/bc-reorder-point).
- **Order Quantity / EOQ** (`Item."Reorder Quantity"`) — how much to order when you do order, balancing the cost of ordering against the cost of holding. Computed by [bc-eoq-calculator](https://github.com/GmsoftLtd/bc-eoq-calculator) with the Wilson formula.

```
Reorder Point = (Average Daily Demand × Lead Time) + Safety Stock
EOQ           = √( (2 × Annual Demand × Ordering Cost) / Holding Cost )
```

Three numbers, three standard fields the planning engine already reads. Now: which policy reads them?

---

## The four policies and the numbers they consume

Business Central's **Reordering Policy** has four meaningful settings. Here is what each one does on a planning run and which of the three numbers it actually uses.

| Reordering Policy | What the engine does | Safety Stock | Reorder Point | EOQ / Reorder Qty. | Maximum Inventory |
|---|---|:---:|:---:|:---:|:---:|
| **Fixed Reorder Qty.** | When projected inventory drops to the reorder point, order a **fixed quantity** | ✔ | ✔ | ✔ | — |
| **Maximum Qty.** | When projected inventory drops to the reorder point, order **up to a maximum** (variable quantity) | ✔ | ✔ | — | ✔ |
| **Lot-for-Lot** | Order **exactly what each demand needs**, netted across a period; no standing stock | ✔ (optional) | — | — (uses Order Multiple/Min. only) | — |
| **Order** | Create **one supply per demand**, pegged together (make-to-order) | — | — | — | — |

Read down the columns and the design tells you something:

- The **reorder point** is consumed by exactly two policies: Fixed Reorder Qty. and Maximum Qty. These are the "keep stock on the shelf and defend a trigger level" policies.
- The **EOQ** is the order size for Fixed Reorder Qty. For Maximum Qty., the order size is *whatever it takes to reach the maximum*, so EOQ isn't read — the **Maximum Inventory** is.
- **Lot-for-Lot** holds no standing stock, so there is no reorder point to defend and no fixed lot to order. Safety stock can still apply if you want a small buffer, but the whole point is to order to demand.
- **Order** pegs supply to demand. None of the three stock numbers apply, by design.

So the policy choice is really one question asked twice:

1. **Do you stock this item at all, or make/buy it to order?** → Order vs. the other three.
2. **If you stock it, do you defend a reorder point (steady demand) or order to each demand (infrequent demand)?** → Fixed Reorder Qty. / Maximum Qty. vs. Lot-for-Lot.
3. **And if you defend a reorder point, do you need to cap inventory?** → Maximum Qty. (cap) vs. Fixed Reorder Qty. (no cap).

## Reading the demand pattern, not guessing it

"Steady" and "infrequent" shouldn't be a gut call. The item's own posted sales tell you, through two numbers:

- **ADI** — *Average Demand Interval*. The mean number of calendar days between days that actually had demand. ADI = 1 means it sells every day; ADI = 30 means roughly once a month.
- **CV²** — the squared *coefficient of variation* of the demand sizes. How erratic the quantity is **when** a sale happens.

The **Syntetos-Boylan-Croston** classification puts those two against standard thresholds (ADI = 1.32, CV² = 0.49):

```
                 CV² < 0.49  (steady size)    CV² >= 0.49  (erratic size)
ADI <  1.32      Smooth                       Erratic          → frequent: defend a reorder point
ADI >= 1.32      Intermittent                 Lumpy            → infrequent: order to demand
```

- **Smooth / Erratic** (frequent — ADI below 1.32): defend a reorder point. Fixed Reorder Qty. or Maximum Qty.
- **Intermittent / Lumpy** (infrequent — ADI at or above 1.32): a reorder point would have you holding stock for weeks between sales. Lot-for-Lot orders to each demand instead.

That gives a clean decision tree:

```
Is the item made/bought to order (Order policy / Make-to-Order)?
 ├─ Yes → ORDER. Supply pegs to demand. The three numbers don't apply.
 └─ No  → Classify demand from posted sales:
          ├─ Infrequent (ADI ≥ 1.32)  → LOT-FOR-LOT
          └─ Frequent  (ADI < 1.32)  → Need to cap inventory (shelf life / max set)?
                                        ├─ Yes → MAXIMUM QTY.
                                        └─ No  → FIXED REORDER QTY.
```

Everything below is that tree, applied.

---

## Worked example 1 — A purchased product (make-to-stock)

**Item 1100, "Brake Pad Set"** — a stocked spare part you buy from a vendor and sell steadily off the shelf.

The three calculators have already run and written their numbers. The cost inputs: unit cost £20, ordering cost £50, holding rate 25%/yr.

| Input | Value | Source |
|---|---|---|
| Average daily demand | 8 / day | sales, last 365 days |
| Lead time | 14 days | purchase-receipt history |
| Safety Stock | 60 | bc-safety-stock (95% service) |
| Annual demand | 2,920 | 8 × 365 |
| Holding cost / unit / yr | £5 | £20 × 25% |

**Reorder Point** = (8 × 14) + 60 = 112 + 60 = **172**
**EOQ** = √( (2 × 2,920 × 50) / 5 ) = √58,400 ≈ **242**

Demand pattern: it sells most working days, steady quantities → **ADI ≈ 1.05, CV² ≈ 0.2 → Smooth.** Frequent demand, no shelf life, no inventory cap needed.

**Recommendation: Fixed Reorder Qty.**

Order a fixed economic lot every time stock crosses the trigger. The BC item card:

| Field | Value |
|---|---|
| Reordering Policy | **Fixed Reorder Qty.** |
| Reorder Point | 172 |
| Reorder Quantity | 242 |
| Safety Stock Quantity | 60 |

On a planning run: when projected inventory falls to 172, BC suggests a purchase of 242. The reorder point covers the 14-day lead time plus the buffer; the EOQ is the cheapest quantity to bring in. All three numbers working together, each in the field its policy reads.

---

## Worked example 2 — A make-to-stock finished good (produced to stock, with a shelf life)

**Item 2200, "Fresh Pasta 500g"** — you manufacture it to stock and sell it from inventory, but it has a 30-day shelf life. Steady, high-volume demand.

| Input | Value | Source |
|---|---|---|
| Average daily demand | 50 / day | sales, last 365 days |
| Manufacturing lead time | 5 days | `Lead Time Calculation` (`<5D>`) |
| Safety Stock | 120 | bc-safety-stock |
| Shelf Life | 30 days | `Item."Shelf Life"` = `<30D>` |

**Reorder Point** = (50 × 5) + 120 = 250 + 120 = **370**

Demand pattern: sells every day, steady → **Smooth.** Frequent demand — so far this looks like example 1. But there is a shelf life. If you ordered a big fixed EOQ each time, you'd build a tall standing stock that risks expiring before it sells. You want to refill *up to a sensible ceiling* and no further.

**Recommendation: Maximum Qty.**

Set a maximum that holds, at most, a few days of cover above the reorder point — comfortably inside the 30-day shelf life. Say **Maximum Inventory = 700** (≈ 6–7 days of demand at the top). When stock crosses 370, BC orders *up to 700* — a variable quantity, never a fixed lot, never overstocking a perishable.

| Field | Value |
|---|---|
| Reordering Policy | **Maximum Qty.** |
| Reorder Point | 370 |
| Maximum Inventory | 700 |
| Safety Stock Quantity | 120 |

Note what changed and what didn't: same demand-during-lead-time maths feeding the reorder point, same safety stock, but the **shelf life flips the order-size decision** from "fixed economic lot" to "refill to a capped maximum." The EOQ field isn't read by this policy — the Maximum Inventory is.

> Rule of thumb: a shelf life, scarce shelf space, or a "don't tie up cash in this" constraint is what turns a Fixed Reorder Qty. item into a Maximum Qty. item. Same trigger, capped fill.

---

## Worked example 3 — A make-to-order machine with stocked components

**Item 3000, "MX-200 Packaging Machine"** — a configured machine you build only when a customer orders one. You do **not** keep finished machines on the shelf.

This is the case most reorder-point tools get wrong, because the right answer is *different policies at different levels of the same BOM*.

### The finished machine: Order

The machine is make-to-order. Manufacturing Policy = Make-to-Order, Reordering Policy = **Order**. Each sales order for an MX-200 creates one production order, pegged to it. There is no stock level to defend, so:

| Field | Value |
|---|---|
| Reordering Policy | **Order** |
| Reorder Point | — (not used) |
| Safety Stock Quantity | — (not used) |
| Reorder Quantity | — (not used) |

Safety stock, reorder point and EOQ **do not apply to the machine.** Trying to set a reorder point on a make-to-order finished good is the classic mistake — you'd be defending a shelf level for something you never put on a shelf.

### But the components underneath are make-to-stock

The MX-200's BOM has components, and *they* are where the three numbers come back. Two representative ones:

**Component 3100, "M8 Bolt"** — cheap, used across many products, consumed constantly.

- High, frequent demand; trivial unit cost; no shelf life.
- Pattern → **Smooth.** No reason to cap.
- **Fixed Reorder Qty.** Reorder Point defends the buy lead time; EOQ is a big cheap lot (ordering bolts often is wasteful).

| Field | Value |
|---|---|
| Reordering Policy | **Fixed Reorder Qty.** |
| Reorder Point | e.g. 800 |
| Reorder Quantity | e.g. 5,000 |
| Safety Stock Quantity | e.g. 300 |

**Component 3200, "MX Control Board"** — expensive, used *only* when an MX-200 is built, which happens a handful of times a year.

- Built ~8 times a year → demand occurs ~8 days out of 365 → **ADI ≈ 46.** Far above 1.32. Infrequent.
- Pattern → **Lumpy.** Holding a reorder-point buffer of a £900 board between sales is dead cash on the shelf.
- **Lot-for-Lot.** Order exactly what each machine build needs, when the production order for the machine creates the demand.

| Field | Value |
|---|---|
| Reordering Policy | **Lot-for-Lot** |
| Reorder Point | — (not used) |
| Safety Stock Quantity | 0 (or a small buffer only if a stockout would idle the line) |
| Order Multiple / Min. Order Qty. | as needed |

So a single make-to-order machine fans out into **three different policies**: Order for the machine, Fixed Reorder Qty. for the commodity bolt, Lot-for-Lot for the expensive lumpy board. Each is the demand pattern at that level talking.

> **A note on the demand signal.** The free extension classifies demand from posted **sales**. A component like the control board is consumed in production, not sold, so its pattern lives in `Consumption` entries, not `Sale` entries — out of scope for the current build (it's on the roadmap). For components, reason about the pattern the same way: *how often is it consumed, and how erratic is the quantity?* The decision tree is identical; only the source of the demand history differs.

---

## Putting it on one screen

Reasoning through ADI, CV², three numbers and a decision tree per item is exactly the kind of thing a small extension should do for you. The free **[bc-replenishment-policy](https://github.com/GmsoftLtd/bc-replenishment-policy)** advisor adds an Item Card action that:

1. Reads the three numbers already on the item (`Safety Stock Quantity`, `Reorder Point`, `Reorder Quantity`) and shows them together.
2. Classifies the item's demand from posted sales (ADI, CV², pattern).
3. Recommends Fixed Reorder Qty., Maximum Qty., Lot-for-Lot, or Order — with the reason in plain English.
4. Optionally writes the recommended Reordering Policy back to the item (off by default — it's advisory until you opt in).
5. Logs every run for audit.

It has **no dependency** on the other three apps — it reads the standard fields whether or not they're installed — and like the rest of the set it's MIT-licensed, free, and changes nothing in standard BC.

The maths told you *what* the numbers are. This tells you *which policy reads them*. That's the set complete: how much to buffer, how much to order, when to order, and the policy that ties all three together.

---

## The set

- [bc-safety-stock](https://github.com/GmsoftLtd/bc-safety-stock) — how much buffer to hold
- [bc-eoq-calculator](https://github.com/GmsoftLtd/bc-eoq-calculator) — how much to order
- [bc-reorder-point](https://github.com/GmsoftLtd/bc-reorder-point) — when to order
- [bc-replenishment-policy](https://github.com/GmsoftLtd/bc-replenishment-policy) — which policy ties them together

Microsoft Learn: [Design details — Reordering policies](https://learn.microsoft.com/dynamics365/business-central/design-details-reordering-policies) · [Planning parameters](https://learn.microsoft.com/dynamics365/business-central/design-details-planning-parameters)

---

*Grigorios Mavrogeorgis — Director and Founder of [GMSOFT Limited](https://gmsoft.co.uk). Microsoft Dynamics 365 Business Central Community Super User, Season 1 2026.*
