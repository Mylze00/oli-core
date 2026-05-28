#!/bin/bash
psql "postgresql://oli_db_user:BFJFnjoDYjIOew7V0uJHCBNbsCaqzj8s@dpg-d5f5o9q4d50c73chl7ng-a.virginia-postgres.render.com/oli_db" -c 'ALTER TABLE wallet_transactions ADD COLUMN IF NOT EXISTS balance_before DECIMAL(15,2) DEFAULT 0, ADD COLUMN IF NOT EXISTS balance_after DECIMAL(15,2) DEFAULT 0;'
