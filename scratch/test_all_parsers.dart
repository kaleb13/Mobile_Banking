import '../lib/services/cbe_birr_parser.dart';
import '../lib/services/telebirr_parser.dart';
import '../lib/services/dashen_parser.dart';

void main() {
  print('=== Running Verification on All Parsers ===\n');

  // Test 1: CBE Birr Airtime Purchase
  const cbeBirrSms =
      "Dear nahom, you bought 170.00Br. of Airtime for 251723185391 on 17/08/26 09:44,Txn ID DHH51LIMBH5 your CBE Birr account balance is 1,450.30Br. Thank you for choosing CBE Birr!";
  final cbeTx = CbeBirrParser.parse(cbeBirrSms, DateTime.now());
  if (cbeTx == null) throw Exception('CBE Birr Airtime failed to parse');
  print('[PASS] CBE Birr Airtime: ID=${cbeTx.id}, Amt=${cbeTx.amount}, Bal=${cbeTx.totalBalance}, Recip=${cbeTx.sender}');

  // Test 2: Telebirr Savings Deposit
  const telebirrDepositSms = '''Dear Kaleb
You have successfully deposited ETB 4000.00 to your Saving Account on 16/08/2026 19:35:27. Your telebirr transaction number is DHG6U8JEIM. Your current Saving balance is ETB 11043.34 and Your current telebirr Account balance is ETB 646.32.
Thank you for using telebirr
Ethio telecom''';
  final depositTx = TelebirrParser.parse(telebirrDepositSms, DateTime.now());
  final depositSavingBal = TelebirrParser.extractSavingBalance(telebirrDepositSms);
  if (depositTx == null) throw Exception('Telebirr Savings Deposit failed to parse');
  if (depositTx.type != 'expense') throw Exception('Deposit should be expense from main wallet');
  if (depositTx.reason != 'Internal Transfer') throw Exception('Reason should be Internal Transfer');
  if (!depositTx.isReasonLocked) throw Exception('Reason should be locked');
  if (depositTx.totalBalance != 646.32) throw Exception('Main balance should be 646.32, got ${depositTx.totalBalance}');
  if (depositSavingBal != 11043.34) throw Exception('Saving balance should be 11043.34, got $depositSavingBal');
  print('[PASS] Telebirr Savings Deposit: ID=${depositTx.id}, Type=${depositTx.type}, Amt=${depositTx.amount}, MainBal=${depositTx.totalBalance}, SavingBal=$depositSavingBal, Reason=${depositTx.reason}, Locked=${depositTx.isReasonLocked}');

  // Test 3: Telebirr Savings Withdrawal
  const telebirrWithdrawSms = '''Dear Kaleb,
You have successfully Withdraw ETB 4000.00 from your saving account on 16/08/2026 17:14:05. Your transaction number is
DHG4U3HNCE. Your current saving balance is ETB 7043.34 and Your current e-money account balance is ETB 4,683.32.
Thank you for using telebirr
Ethio telecom''';
  final withdrawTx = TelebirrParser.parse(telebirrWithdrawSms, DateTime.now());
  final withdrawSavingBal = TelebirrParser.extractSavingBalance(telebirrWithdrawSms);
  if (withdrawTx == null) throw Exception('Telebirr Savings Withdrawal failed to parse');
  if (withdrawTx.type != 'income') throw Exception('Withdrawal should be income to main wallet');
  if (withdrawTx.reason != 'Internal Transfer') throw Exception('Reason should be Internal Transfer');
  if (!withdrawTx.isReasonLocked) throw Exception('Reason should be locked');
  if (withdrawTx.totalBalance != 4683.32) throw Exception('Main balance should be 4683.32, got ${withdrawTx.totalBalance}');
  if (withdrawSavingBal != 7043.34) throw Exception('Saving balance should be 7043.34, got $withdrawSavingBal');
  print('[PASS] Telebirr Savings Withdrawal: ID=${withdrawTx.id}, Type=${withdrawTx.type}, Amt=${withdrawTx.amount}, MainBal=${withdrawTx.totalBalance}, SavingBal=$withdrawSavingBal, Reason=${withdrawTx.reason}, Locked=${withdrawTx.isReasonLocked}');

  // Test 4: Dashen Bank Deposit & Owner Name
  const dashenDepositSms =
      "Dear Customer, ABREHAHSILASSIEHIRUY has deposited ETB 8,000.00 to your account '5016******005' on 29/01/2024. Your current balance is ETB 368,464.98.\nDashen Bank - Always one step ahead!";
  final dashenDepositTx = DashenParser.parse(dashenDepositSms, DateTime.now());
  if (dashenDepositTx == null) throw Exception('Dashen deposit failed');
  if (dashenDepositTx.amount != 8000.0) throw Exception('Dashen deposit amount mismatch');
  if (dashenDepositTx.totalBalance != 368464.98) throw Exception('Dashen balance mismatch');
  if (dashenDepositTx.name != 'Dashen Bank') throw Exception('Dashen bank name mismatch');
  if (dashenDepositTx.sender != 'ABREHAHSILASSIEHIRUY') throw Exception('Dashen party mismatch');
  print('[PASS] Dashen Bank Deposit: ID=${dashenDepositTx.id}, Bank=${dashenDepositTx.name}, Amt=${dashenDepositTx.amount}, Bal=${dashenDepositTx.totalBalance}, Party=${dashenDepositTx.sender}');

  // Test 5: Dashen Bank Withdrawal & Owner Name
  const dashenOwnerSms =
      "Dear, Nahom Your Account '5017******011' has been credited with ETB 7,000.00 from other bank on 04/02/2026. your current balance is ETB 39,226.94.\nDashen Bank - Always one step ahead!";
  final dashenOwner = DashenParser.extractOwnerName(dashenOwnerSms);
  final dashenOwnerTx = DashenParser.parse(dashenOwnerSms, DateTime.now());
  if (dashenOwner != 'Nahom') throw Exception('Dashen owner name extraction failed');
  if (dashenOwnerTx == null || dashenOwnerTx.amount != 7000.0) throw Exception('Dashen credited failed');
  print('[PASS] Dashen Bank Owner & Credit: Owner=$dashenOwner, Amt=${dashenOwnerTx.amount}, Bal=${dashenOwnerTx.totalBalance}');

  print('\nAll parser verifications passed successfully! 🎉');
}
