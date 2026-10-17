---
title: Payroll
group: Accounting
who: Accounting, administrators
summary: Salary grades, variables, formulas; generate payslips by period, adjust manually, approve, mark as paid, export payslips.
---

Open **Payroll**. It has four tabs: **Payroll**, **Salary Grades**, **Variables**, **Formulas**. Set up the last three once, then each month
you only need to generate, check, approve and pay in the first tab.

## Salary grades

Each grade is a group with its own way of paying: **daily** or **hourly**, with a rate. An employee is linked to one grade (in their profile). A grade that employees use (now or in their job history) cannot be deleted: change those employees' grade first.

![Salary grades](img:salary-grades)

## Variables

Custom variables (attendance bonus, coefficients, etc.) used in formulas. There are also built-in **system variables** that BossKin calculates from data:

| Variable | Meaning |
|---|---|
| `STANDARD_WORK_DAYS`, `PRESENT_DAYS` | Standard working days of the period, actual days worked |
| `PAID_LEAVE_DAYS`, `UNPAID_LEAVE_DAYS`, `LATE_IN_DAYS` | Paid / unpaid leave days, number of late days |
| `DAY_HOURS`, `NIGHT_HOURS`, `DAY_OT`, `NIGHT_OT`, `TOTAL_OT_HOURS` | Day / night shift hours, overtime hours |
| `CONTRACT_SALARY`, `ALLOWANCE_<code>` | Salary and allowances under the contract / appendix in effect during the period |
| `INSURANCE_BASE`, `SOCIAL_INS`, `HEALTH_INS`, `UNEMPLOYMENT_INS`, `TOTAL_INSURANCE` | Insurance salary (with floor / cap applied) and each insurance contribution paid by the employee |
| `PIT` | Personal income tax (PIT) calculated under the current tax table |
| `PERSONAL_DEDUCTION`, `DEPENDENTS`, `FAMILY_DEDUCTION` | Personal deduction, number of dependents, total family deduction |
| `HOLIDAY_DAYS`, `HOLIDAY_OT_HOURS` | Paid holiday days, hours worked on holidays |

![Variables](img:salary-variables)

## Salary formulas

Each salary grade has a **GROSS** (total pay) and a **NET** (take-home pay) formula, effective from a date. Write them with variables, operators, `IF(...)`,
`ROUND(...)` and `PIT_VN(taxable income)`. Example:

```
GROSS:  CONTRACT_SALARY * PRESENT_DAYS / STANDARD_WORK_DAYS + CONTRACT_ALLOWANCE + BONUS
NET:    GROSS - TOTAL_INSURANCE - PIT
```

![Salary formulas](img:salary-formulas)

> **Note:** Family deduction amounts, the tax table and insurance caps are updated by the system administrator according to the law (by effective date); a payroll period uses the
> policy in effect on the **last day of the period**. Do not hard-code these numbers in formulas.

## Generate the monthly payroll

1. Make sure the period's attendance is **approved** and (preferably) the **attendance period is locked**.
2. In the **Payroll** tab click **Generate payroll**.
3. Choose **Month / Year**; leave the employee field empty to generate for everyone in your scope, or search and add people one by one, then click **Create**.

![Generate payroll](img:payroll-generate)

If a formula fails for someone, the system tells you exactly which person and which variable caused the error.

## Check, adjust, approve, pay

The monthly payslip list shows base salary, gross pay, net pay, days worked and the status **Draft → Approved → Paid**.

![September payroll](img:payroll-list)

- **View details** — every line item. A draft payslip can have bonuses / deductions entered manually and then be **recalculated**.
- Select several payslips (checkbox on the right) to **approve** or **mark as paid** in bulk.
- **Export payslips** to Excel (includes the employer insurance contribution and total cost columns).

> **Important:** No one can approve, edit or pay their own payslip; someone else must do it. Employees only see a payslip once it has been approved.
