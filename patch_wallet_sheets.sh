#!/bin/bash
set -e
cd /home/paolice-mylze/oli-core/oli_app/lib/features/wallet/widgets

FILE="wallet_action_sheets.dart"

# 1. Ajouter l'import du deposit_status_dialog après la dernière ligne import
IMPORT_LINE="import 'deposit_status_dialog.dart';"
if ! grep -q "deposit_status_dialog" "$FILE"; then
  sed -i "9a $IMPORT_LINE" "$FILE"
  echo "✅ Import ajouté"
else
  echo "⚠️  Import déjà présent"
fi

# 2. Remplacer le bloc onSubmit du dépôt Mobile Money (RechargerSheet)
# On remplace le callback onSubmit de la RechargerSheet pour utiliser DepositResult
python3 << 'PYEOF'
import re

with open("wallet_action_sheets.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Cherche le callback onSubmit du RechargerSheet (deposit)
old_block = """                onSubmit: (amount, provider, phone) async {
                  final ok = await ref
                      .read(walletProvider.notifier)
                      .deposit(amount: amount, provider: provider, phone: phone);
                  return ok;
                },"""

new_block = """                onSubmit: (amount, provider, phone) async {
                  // Lance le dépôt et récupère l'oliOrderId pour le popup de statut
                  final result = await ref
                      .read(walletProvider.notifier)
                      .deposit(amount: amount, provider: provider, phone: phone);
                  if (result.success && result.oliOrderId != null) {
                    // Fermer le formulaire
                    if (context.mounted) Navigator.pop(context);
                    // Afficher le popup de suivi
                    if (context.mounted) {
                      await showDepositStatusDialog(
                        context: context,
                        ref: ref,
                        orderId: result.oliOrderId!,
                        amountFC: amount,
                      );
                    }
                    return true;
                  }
                  return result.success;
                },"""

if old_block in content:
    content = content.replace(old_block, new_block, 1)
    print("✅ onSubmit RechargerSheet modifié")
else:
    print("⚠️  Bloc onSubmit non trouvé exactement, tentative pattern partiel...")
    # Try more flexible match
    pattern = r"onSubmit: \(amount, provider, phone\) async \{[^}]+\.deposit\(amount: amount, provider: provider, phone: phone\);\s*return ok;\s*\},"
    if re.search(pattern, content, re.DOTALL):
        content = re.sub(pattern, new_block, content, count=1, flags=re.DOTALL)
        print("✅ onSubmit modifié via regex")
    else:
        print("❌ Impossible de trouver le bloc onSubmit")

with open("wallet_action_sheets.dart", "w", encoding="utf-8") as f:
    f.write(content)

PYEOF

echo "Terminé"
