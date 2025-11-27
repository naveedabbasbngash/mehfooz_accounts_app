📱 Mehfooz Accounts App

Offline-First Personal Ledger & Financial Reporting System (Flutter + Drift + MVVM)

A cross-platform financial management app built using Flutter, designed as an offline-first solution with secure and optimized synchronization support for future expansions.
Supports Android, iOS, and Web.

⸻

🚀 Overview

Mehfooz Accounts App is a complete financial ledger & reporting system that allows users to:

	•	Import and validate external SQLite databases
	•	View accounts, balances, transactions, and ledger details
	•	Generate professional PDF reports (Balance Report, Credit, Debit, Pending, Ledger)
	•	Use advanced filters (date range, debit/credit modes, balance mode)
	•	Work fully offline, using a robust database engine powered by Drift (Moor)
	•	Sync-ready architecture for future API integration

This project is a Kotlin → Flutter migration and follows a strict MVVM architecture with a clean separation of:

	•	UI (Screens / Widgets)
	•	ViewModels
	•	Repositories
	•	Drift database layer
	•	Services (PDF generator, logging, import validation)
