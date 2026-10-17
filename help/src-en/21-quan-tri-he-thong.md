---
title: System administration (provider)
group: Administration
who: BossKin system administrators (not company administrators)
summary: The /admin portal: customer companies, trial requests, administrators, tax & insurance parameters, template holidays.
---

The system admin portal is at `/admin`, with separate accounts and **mandatory two-factor authentication**.

![System admin sign-in](img:admin-login)

## Companies

Create customer companies (with their first admin account), edit company details (pencil button), lock / unlock a company, require 2FA for a company's
administrators (shield button), and **sign in on behalf** to give support (arrow button) — while viewing on behalf, the app shows a warning banner and every action is logged.

When creating a company:

- **Company code**: 2–12 uppercase letters / digits, starting with a letter (for example `TH`). This code is the **employee code prefix** (`TH00001`…), so it
  must be unique and must not be the start of another company's code (if `TH` exists you cannot create `THA`). It **cannot be changed** after creation —
  the edit dialog shows the code read-only.
- **Email domain** is required (for example `th.com`) and must not match another company. Every account in the company — the first admin, employees created
  by form or Excel import, any extra accounts — must have an email `…@th.com`. The domain can only be changed when no account still uses the old domain.

**Feature packages:** in the edit dialog (pencil button), tick the packages the company may use — *Attendance*, *Shifts*, *Leave*, *Payroll*,
*Labor contracts*, *Employee documents*, *Reports*. For example, if a company only bought attendance + shifts + payroll, untick the other three packages.
A disabled package: the menu is hidden for everyone in the company (admins included), the API returns an error, and existing data is kept — turn it back on to resume. Attendance needs Shifts
(ticking Attendance ticks Shifts automatically). Employees, departments, permissions and company settings are always available. Each change is logged as `COMPANY_MODULES`.
People who are signed in see the change after signing in again (or when the session refreshes itself, within 30 minutes at most).

![Company list](img:admin-tab-2)

## Trial requests

Requests submitted from the landing page. Filter by status (New, Contacted, Trialing, Not a fit), add notes, export to Excel.

![Trial requests](img:admin-tab-3)

## Administrators

Create system administrators (auto-generated password, shown once), lock / unlock, reset passwords, remove 2FA. There is always at least one active administrator; you cannot act on
yourself.

![Administrators](img:admin-tab-4)

## Tax & insurance

Parameters shared by all companies, by **effective date**: personal deduction, dependent deduction, progressive tax brackets, the reference level
and multiplier for the BHXH/BHYT cap, the 4-region minimum wage and the multiplier for the BHTN cap. When the law changes, **Add policy** with a new effective date — past
payroll periods are still computed with the old policy.

![Tax & insurance](img:admin-tab-5)

## Holiday template

The template holiday list by year for every company that has not customised its own. Update compensatory / swapped days according to the official yearly announcement.

![Holiday template](img:admin-tab-6)
