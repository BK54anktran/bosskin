---
title: Shifts and shift assignment
group: Manager
who: Shift managers, HR
summary: Create shifts (fixed, flexible, overnight), assign shifts to employees, quick fill, rotation patterns, approve shift swaps.
---

## Shift list

Open **Shifts** → the **Shift list** tab. Each shift has a code, start – end time, mid-shift break and working hours.

![Shift list](img:shift-list)

### Create a new shift

1. Click **Create shift**.
2. Enter the **Shift name** and **Shift code** (short, shown on the assignment grid), and a shift group if you like.
3. Choose the type: **Fixed hours** (fixed in – out) or **Flexible** (the required hours within a time window; missing hours count as late).
4. Enter the start / end time and the break (if any). A shift that ends after midnight is treated as an **overnight shift**.
5. Choose a color and the departments it applies to → **Create shift**.

![Create shift dialog](img:shift-new)

## Shift assignments

The **Shift assignments** tab is a grid: rows are employees, columns are the days of the period (based on the company's payroll cut-off day).

1. Choose the period with the arrows next to the month; filter by department / search for an employee if needed.
2. Click a cell (employee × day) to pick a shift; at most 4 shifts per day, and shifts must not overlap.
3. **Quick fill shift**: open the shift panel on the right, pick a shift, then click several consecutive cells to fill them.

![Shift assignment grid](img:shift-assign)

![Quick fill shift](img:shift-quickfill)

A shift cannot be removed from a day that already has attendance data (checked in/out, attendance approved, or an approved time-correction request in effect). If a time-correction request is **pending**, approve or reject it first; requests that were rejected, cancelled or deactivated (times struck through on the timesheet) do not block removing the shift. **Export / Import Excel** uses a horizontal sheet (employee × day, cells are shift codes), with a preview
before importing.

## Rotation patterns

For teams working rotating shifts (e.g. 6 days of shift 1 – 6 days of shift 2 – 2 days off).

1. **Rotations** tab → **Add rotation**: set a name, the cycle length, and pick a shift for each day (leave blank = day off).
2. Click **Apply to employees** on the pattern: choose the employees, the start date, each person's day offset and the date range to generate.
3. Optionally **Skip holidays**. Days that already have attendance are left untouched.

![Rotation pattern](img:shift-rotation)

## Work schedule registration

When the company turns on **Work schedule registration** (Company settings → General), Shifts gains a **Registration** tab for people with permission to manage schedule registration.

1. Click **New registration round**: set a name, quickly pick *Next week* / *Next 2 weeks* / *Next month* or choose from date – to date (up to 62 days),
   pick departments, the deadline (the round closes automatically then) and limits if needed (allowed time windows, hours per window, minimum days, people needed per day).
2. **Save and open** — employees in those departments get a notification. You can **Close** / **Reopen** any round at any time right from the list.
3. Click a round to see the people × days grid. Each day column shows people / needed and an **Approve (n)** button: it approves all pending registrations for that day and creates the assignments straight away.
   People who registered as *free all day* need a shift chosen when approving. Registrations that duplicate an existing assignment are skipped and reported.
4. Click a pending cell to approve it individually, change it to another shift / time, or reject it. Click a day heading to see the headcount by hour.
   An approved cell (green) shows the assigned shift and time; hover over a cell to see what the employee registered.

Registration is only a preference — managers still assign shifts as usual in **Shift assignments**.

## Approve shift swaps

Open **Shift swaps** → filter **Pending**. Each request shows who swaps with whom, the shifts and the date. Click **Approve** or **Reject**.

![Approve shift swap request](img:swap-approve)
