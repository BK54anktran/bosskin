---
title: Company settings
group: Administration
who: Company administrator
summary: Attendance, leave, request approvers, contract alerts, payroll and insurance, check-in location, weekly work calendar, holidays.
---

Open **Company settings** (bottom of the menu). Two tabs: **General** and **Work calendar**.

## General tab

![Attendance, leave and approver settings](img:settings-general)

| Item | Meaning |
|---|---|
| Day / night mode, Enable OT mode | Separates night-shift hours; allows overtime registration |
| Leave settings | How many hours equal 1 leave day (for hourly leave requests) |
| **Request approval** | *By permission and scope* (default) or *Direct manager approves first, then HR* |
| Schedule registration | On: employees get the *Schedule registration* menu, and Shifts gets a *Registration* tab where managers open / close rounds and approve them into shift assignments |
| Contract expiry warning | Number of days (default 30) — contracts / documents expiring within this many days show a warning |
| **Time zone** | The company's local time (default Asia/Ho_Chi_Minh). Attendance, shifts, "today", work dates and shift reminders are all computed in this time zone — a company in Thailand, Japan, etc. should pick the right time zone to avoid shifted dates / false late marks. Changing it when data already exists only applies from the moment of the change. Daily background jobs (leave accrual, contract / document reminders) still run on Vietnam time |
| **Currency** | The unit used to display amounts (VND, USD, THB, JPY…): symbol and decimals in payroll, costs and the Dashboard. This only changes the display and **does not convert** entered amounts; tax and insurance default to Vietnamese regulations |

![Payroll and insurance](img:settings-general-2)

| Item | Meaning |
|---|---|
| Standard days from work calendar | On: the standard working days of each period are counted from the department's weekly calendar and holidays. Off: use the fixed number below |
| Standard working days / month | Default 22 |
| Payroll cutoff day | The day a period starts (1–28). E.g. 25 → the May period is 25/4–24/5 |
| Minimum wage region | Region I–IV, used to compute the unemployment insurance (BHTN) cap and the insured-salary floor |
| Employer insurance rates | Social insurance (BHXH) 17.5% · health insurance (BHYT) 3% · BHTN 1% (shown in cost reports, not deducted from pay) |

![Check-in location and devices](img:settings-general-3)

| Item | Meaning |
|---|---|
| Enable location-based check-in | Requires employees to be within a radius of the company location (or the department's own location). Set the location on the map, with the **Use current location** button, the **Paste Google Maps link** button (paste a place link, including shortened links, and the system extracts the coordinates) or enter latitude / longitude |
| Only allow check-in from the bound device | The first check-in binds the device; other devices are blocked. To switch devices, HR removes the device in the employee's profile |
| Allow check-in / check-out without a scheduled shift | On days with no shift, employees can still check in / out multiple times (each pair is one attendance row; a new pass cannot start until the previous one is checked out): attendance is not tied to a shift, lateness is not evaluated, hours follow actual time, and approval is still required. On days with a shift, check-in still follows the shift window |
| Check-in / out time range | How many minutes early / late employees may check in around the shift time |

Remember to click **Save** at the bottom of the page.

## Work calendar tab

![Weekly work calendar and holidays](img:settings-calendar)

### Weekly calendar

Each calendar defines, for every weekday, a **full day**, a **half day** or a **day off**. The *default calendar* applies to every department without its own calendar.

1. Click **Add calendar** and name it (e.g. "Workshop: Sat morning").
2. Click each weekday to cycle full day → half day → day off.
3. Tick the **departments** that use this calendar → **Save**. Child departments without a calendar use their parent's calendar.

![Add a work calendar](img:calendar-new)

### Holidays

A list by year (arrows change the year). By default the company uses the **system template** (New Year, Lunar New Year, Hung Kings' Day, 30/4, 1/5, 2/9…).
The first time you add / edit / delete a day in a given year, that year's template is copied into the company's own list.

- **Add holiday**: date, name, type (*Holiday*, *Compensatory day off*, *Swapped workday*), and whether it is paid.
- **Export / Import Excel** to import the Tet holiday schedule from the yearly announcement (with preview); **Download template** gives a blank file with instructions.

Effects: leave requests do not count holidays, the shift grid and attendance sheet colour holidays, and payroll gets `HOLIDAY_DAYS` (paid holidays) and
`HOLIDAY_OT_HOURS` (hours worked on holidays).
