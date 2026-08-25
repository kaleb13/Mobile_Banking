class BankAccountItem {
  final int? simSlot; // null = Combined / All SIMs
  final String label;
  final double balance;
  final int txCount;
  final bool isPaused;

  const BankAccountItem({
    this.simSlot,
    required this.label,
    required this.balance,
    required this.txCount,
    this.isPaused = false,
  });
}
