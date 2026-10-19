import 'app_localizations.dart';

extension FuelLocalizations on AppLocalizations {
  String fuel(String key) {
    final value = _fuelCopy[key]!;
    return isArabic ? value.$2 : value.$1;
  }
}

const _fuelCopy = <String, (String, String)>{
  'fullIntervalsLabel': ('Full-to-full intervals', 'فترات بين تعبئتين كاملتين'),
  'unitSetting': ('Fuel consumption unit', 'وحدة استهلاك الوقود'),
  'unitSaveError': (
    'Couldn’t save the unit. Please try again.',
    'تعذر حفظ الوحدة. حاول مرة أخرى.',
  ),
  'chartTitle': ('Fuel consumption', 'استهلاك الوقود'),
  'demo': ('Demo data', 'بيانات تجريبية'),
  'vehicleData': ('My vehicle', 'مركبتي'),
  'demoNotice': (
    'Sample data only — not saved to your vehicle.',
    'بيانات للعرض فقط — لا تُحفظ في مركبتك.',
  ),
  'previousInterval': (
    'Previous full-to-full interval',
    'الفترة الكاملة السابقة',
  ),
  'nextInterval': ('Next full-to-full interval', 'الفترة الكاملة التالية'),
  'fullIntervals': (
    'Full-to-full intervals · km/L',
    'فترات بين تعبئتين كاملتين · كم/لتر',
  ),
  'viewValues': ('View chart values', 'عرض قيم الرسم البياني'),
  'add': ('Add Fuel', 'إضافة وقود'),
  'edit': ('Edit fuel fill', 'تعديل تعبئة الوقود'),
  'grade': ('Fuel grade', 'نوع البنزين'),
  'amountMode': ('By amount', 'بالمبلغ'),
  'litersMode': ('By litres', 'باللترات'),
  'price': ('Pump price (EGP/L)', 'سعر المحطة (جنيه/لتر)'),
  'effective': (
    'Effective price saved (EGP/L)',
    'السعر الفعلي المحفوظ (جنيه/لتر)',
  ),
  'amount': ('Amount paid (EGP)', 'المبلغ المدفوع (جنيه)'),
  'liters': ('Litres added', 'اللترات المضافة'),
  'litersUnit': ('L', 'لتر'),
  'date': ('Fill date', 'تاريخ التعبئة'),
  'time': ('Fill time', 'وقت التعبئة'),
  'fullQuestion': ('Full tank?', 'تم ملء الخزان بالكامل؟'),
  'full': ('Full tank', 'خزان ممتلئ'),
  'partial': ('Partial fill', 'تعبئة جزئية'),
  'unknown': ('Tank status not recorded', 'لم تُسجل حالة الخزان'),
  'usual': (
    'Use this as this vehicle’s usual grade',
    'استخدم هذا النوع افتراضياً لهذه المركبة',
  ),
  'usualGrade': ('Usual fuel grade', 'نوع البنزين الافتراضي'),
  'review': ('Review before saving', 'راجع البيانات قبل الحفظ'),
  'receipt': (
    'Edit either amount or litres; the other is calculated automatically using the pump price.',
    'عدّل المبلغ أو اللترات؛ تُحسب القيمة الأخرى تلقائياً باستخدام سعر المحطة.',
  ),
  'positive': (
    'Enter a finite number greater than zero.',
    'أدخل رقماً صحيحاً أكبر من صفر.',
  ),
  'odometerError': (
    'Enter an odometer from 0 to 999999 km.',
    'أدخل قراءة عداد من 0 إلى 999999 كم.',
  ),
  'orderError': (
    'The odometer must fit between the earlier and later fills. Check the date and reading.',
    'يجب أن تتوافق قراءة العداد مع التعبئة السابقة والتالية. راجع التاريخ والقراءة.',
  ),
  'future': (
    'The fill date/time cannot be in the future.',
    'لا يمكن أن يكون تاريخ ووقت التعبئة في المستقبل.',
  ),
  'saveError': (
    'Couldn’t save. Your entries are still here; please try again.',
    'تعذر الحفظ. بياناتك ما زالت موجودة؛ حاول مرة أخرى.',
  ),
  'latest': ('Latest fill', 'آخر تعبئة'),
  'spending': ('Total fuel spending', 'إجمالي تكلفة الوقود'),
  'economy': ('Latest reliable consumption', 'آخر استهلاك موثوق'),
  'needsFull': (
    'Needs another full fill after a known full tank.',
    'يلزم ملء الخزان بالكامل مرة أخرى بعد تعبئة كاملة مسجلة.',
  ),
  'history': ('Fuel history', 'سجل الوقود'),
  'delete': ('Delete fuel fill?', 'حذف تعبئة الوقود؟'),
  'deleteBody': (
    'This cannot be undone. Consumption across the missing record will be withheld until a new valid full-to-full interval exists.',
    'لا يمكن التراجع. لن يُعرض استهلاك الفترة التي ينقصها هذا السجل حتى تتوفر فترة كاملة موثوقة جديدة.',
  ),
  'deleteAction': ('Delete fill', 'حذف التعبئة'),
  'deletedError': (
    'Couldn’t delete this fill. Please try again.',
    'تعذر حذف التعبئة. حاول مرة أخرى.',
  ),
  'gap': (
    'A missing record interrupts consumption here.',
    'سجل مفقود يمنع حساب الاستهلاك هنا.',
  ),
  'note': ('Note (optional)', 'ملاحظة (اختياري)'),
  'none': ('No fill recorded', 'لم تُسجل تعبئة'),
  'kmL': ('km/L', 'كم/لتر'),
  'l100': ('L/100 km', 'لتر/100 كم'),
  'egp': ('EGP', 'جنيه'),
  'view': ('Fuel fill details', 'تفاصيل تعبئة الوقود'),
};
