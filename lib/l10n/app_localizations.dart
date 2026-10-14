import 'package:flutter/material.dart';

/// Localized copy for the GearTracker app.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ar')];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';

  String get remainingLifespan =>
      isArabic ? 'العمر المتبقي' : 'Remaining lifespan';
  String get used => isArabic ? 'المستخدم' : 'Used';
  String get interval => isArabic ? 'الفترة' : 'Interval';
  String get left => isArabic ? 'متبقي' : 'left';
  String get kilometers => isArabic ? 'كم' : 'km';
  String get kilometersFieldSuffix =>
      isArabic ? '\u00a0كم' : kilometers.toUpperCase();
  String get editServiceHint => isArabic ? 'تعديل الصيانة' : 'Edit service';
  String get markServiced => isArabic ? 'تسجيل إتمام الصيانة' : 'Mark serviced';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get edit => isArabic ? 'تعديل' : 'Edit';
  String get serviceConfigurationInstruction => isArabic
      ? 'يغيّر هذا إعدادات الصيانة. استخدم «تسجيل إتمام الصيانة» عند استبدال الجزء.'
      : 'This changes the service configuration. Use Mark serviced when the service has been replaced.';
  String get addService => isArabic ? 'إضافة صيانة' : 'Add service';
  String get serviceDetails => isArabic ? 'تفاصيل الصيانة' : 'Service details';
  String get serviceName => isArabic ? 'اسم الصيانة' : 'Service name';
  String get enterServiceName =>
      isArabic ? 'أدخل اسم الصيانة' : 'Enter a service name';
  String get note => isArabic ? 'ملاحظة' : 'Note';
  String get serviceNoteHint =>
      isArabic ? 'مثلاً، زيت صناعي 5W-40' : 'For example, 5W-40 SYN';
  String get enterServiceNote => isArabic ? 'أدخل ملاحظة' : 'Enter a note';
  String get serviceInterval =>
      isArabic ? 'تقدير الفاصل الزمني' : 'Interval estimate';
  String get enterPositiveServiceInterval => isArabic
      ? 'أدخل فترة أكبر من 0 كم'
      : 'Enter an interval greater than 0 km';
  String get selectServiceInstallDate =>
      isArabic ? 'اختر تاريخ تركيب الصيانة' : 'Select service install date';
  String get submitting => isArabic ? 'جارٍ الحفظ…' : 'Saving…';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Retry';
  String get loadingGarage =>
      isArabic ? 'جارٍ تحميل المرآب…' : 'Loading garage…';
  String get garageLoadFailed => isArabic
      ? 'تعذر تحميل المرآب. حاول مرة أخرى.'
      : 'Couldn’t load your garage. Try again.';
  String get emptyGarageTitle =>
      isArabic ? 'مرآبك فارغ' : 'Your garage is empty';
  String get emptyGarageMessage => isArabic
      ? 'أضف مركبتك الأولى للبدء في تتبع الصيانة.'
      : 'Add your first vehicle to start tracking maintenance.';
  String get addVehicle => isArabic ? 'إضافة مركبة' : 'Add vehicle';
  String get emptyVehicleRecordsTitle =>
      isArabic ? 'لا توجد سجلات بعد' : 'No records yet';
  String get emptyVehicleRecordsMessage => isArabic
      ? 'أضف صيانة أو حالة الإطارات لبدء تتبع هذه المركبة.'
      : 'Add a service or tire health entry to start tracking this vehicle.';
  String get noServicesYet =>
      isArabic ? 'لا توجد صيانة بعد' : 'No services yet';
  String get noServicesMessage => isArabic
      ? 'أضف صيانة لبدء تتبع مواعيد الاستحقاق.'
      : 'Add a service to start tracking due dates.';
  String get noTireHealthYet =>
      isArabic ? 'لا توجد حالة إطارات بعد' : 'No tire health yet';
  String get noTireHealthMessage => isArabic
      ? 'أضف حالة الإطارات لتتبع عمر الإطارات.'
      : 'Add tire health to track tire lifespan.';
  String get tireHealthGuideMessage => isArabic
      ? 'مثال: أضف حالة الإطارات لتتبع عمر كل إطار وموعد فحصه.'
      : 'Example: add Tire Health to track each tire and know when it needs inspection.';
  String get addTireHealth =>
      isArabic ? 'إضافة حالة الإطارات' : 'Add tire health';
  String get tireHealthSetupTitle =>
      isArabic ? 'إعداد حالة الإطارات' : 'Set up Tire Health';
  String tireHealthStep(int step, int total) =>
      isArabic ? 'الإطار $step من $total' : 'Tire $step of $total';
  String get tireHealthFirstTireHint => isArabic
      ? 'أدخل بيانات الإطار الأول. ستُقترح هذه القيم للإطارات التالية.'
      : 'Enter the first tire details. These values will be suggested for the next tires.';
  String get tireHealthCopyPreviousHint => isArabic
      ? 'تم نسخ بيانات الإطار السابق. عدّلها إذا احتاج هذا الإطار إلى قيم مختلفة.'
      : 'The previous tire details were copied. Adjust them if this tire is different.';
  String get nextAction => isArabic ? 'التالي' : 'Next';
  String get finish => isArabic ? 'إنهاء' : 'Finish';
  String get saving => isArabic ? 'جارٍ الحفظ…' : 'Saving…';
  String get saved => isArabic ? 'تم الحفظ' : 'Saved';
  String get unsavedChanges =>
      isArabic ? 'تغييرات غير محفوظة' : 'Unsaved changes';
  String get saveFailed => isArabic ? 'تعذر الحفظ' : 'Save failed';
  String get changesSaveFailed => isArabic
      ? 'تعذر حفظ التغييرات. حاول مرة أخرى.'
      : 'Couldn’t save changes.';
  String get serviceSaveFailed => isArabic
      ? 'تعذر حفظ الصيانة. حاول مرة أخرى.'
      : 'Couldn’t save service. Try again.';
  String get tireHealth => isArabic ? 'حالة الإطارات' : 'Tire Health';

  /// Add-service picker tile label. Keeps the lower-case "health" used on the
  /// picker card, which differs from the [tireHealth] health-card header.
  String get tireHealthService => isArabic ? 'حالة الإطارات' : 'Tire health';
  String tirePosition(String id) => switch (id) {
    'front-left' => isArabic ? 'الإطار الأمامي الأيسر' : 'Front left tire',
    'front-right' => isArabic ? 'الإطار الأمامي الأيمن' : 'Front right tire',
    'back-left' => isArabic ? 'الإطار الخلفي الأيسر' : 'Back left tire',
    'back-right' => isArabic ? 'الإطار الخلفي الأيمن' : 'Back right tire',
    _ => isArabic ? 'إطار' : 'Tire',
  };
  String get editTireHint => isArabic ? 'تعديل الإطار' : 'Edit tire';
  String tireSummary({
    required String position,
    required String status,
    required String remainingPercent,
    required String remainingKm,
  }) => isArabic
      ? '$position، الحالة: $status، $remainingPercent٪، $remainingKm $kilometers $left'
      : '$position, $status, $remainingPercent%, $remainingKm $kilometers $left';
  String tireRemaining({required String percent, required String distance}) =>
      isArabic
      ? '$percent٪ · $distance $kilometers $left'
      : '$percent% · $distance $kilometers $left';
  String tireProgressLabel(String percent) =>
      isArabic ? 'العمر المتبقي: $percent٪' : 'Remaining lifespan: $percent%';
  String tireAgeDue(String date) =>
      isArabic ? 'حد العمر: $date' : 'Age limit: $date';
  String get editTire => isArabic ? 'تعديل الإطار' : 'Edit tire';
  String editTireTitle(String code) =>
      isArabic ? 'تعديل الإطار $code' : 'Edit $code Tire';
  String currentOdometer(String distance) => isArabic
      ? 'عداد المسافة الحالي: $distance $kilometers'
      : 'Current odometer: $distance $kilometers';
  String installDate(String date) =>
      isArabic ? 'تاريخ تركيب الإطار: $date' : 'Install date: $date';
  String get selectTireInstallDate =>
      isArabic ? 'اختر تاريخ تركيب الإطار' : 'Select tire install date';
  String get installationOdometer =>
      isArabic ? 'عداد المسافة عند التركيب' : 'Installation odometer';
  String get tireLifespanInterval =>
      isArabic ? 'فترة عمر الإطار' : 'Tire lifespan interval';
  String get tireAgeDuration => isArabic ? 'عمر الإطار' : 'Tire age limit';
  String get months => isArabic ? 'شهراً' : 'months';
  String get enterPositiveDuration =>
      isArabic ? 'أدخل مدة أكبر من صفر' : 'Enter a duration greater than 0';
  String get enterValidInstallationDistance => isArabic
      ? 'أدخل قراءة صالحة لعداد المسافة عند التركيب'
      : 'Enter a valid installation km';
  String get installationDistanceCannotExceedCurrent => isArabic
      ? 'لا يمكن أن تتجاوز قراءة التركيب القراءة الحالية'
      : 'Installation km cannot exceed current km';
  String get enterPositiveTireInterval => isArabic
      ? 'أدخل فترة أكبر من 0 كم'
      : 'Enter an interval greater than 0 km';
  String get saveTire => isArabic ? 'حفظ الإطار' : 'Save tire';
  String tireSaved(String code) =>
      isArabic ? 'تم حفظ الإطار $code' : '$code tire saved';
  String get tireSaveFailed => isArabic
      ? 'تعذر حفظ الإطار. حاول مرة أخرى.'
      : 'Couldn’t save tire. Try again.';
  String serviceMarked(String name) =>
      isArabic ? 'تم تسجيل إتمام صيانة $name' : '$name marked as serviced';

  String serviceSummary({
    required String name,
    required String status,
    required String remainingPercent,
    required String remainingKm,
  }) => isArabic
      ? '$name، الحالة: $status، $remainingPercent٪، $remainingKm $kilometers $left'
      : '$name, $status, $remainingPercent%, $remainingKm $kilometers $left';

  String remaining({required String percent, required String distance}) =>
      isArabic
      ? '$percent٪ · $distance $kilometers $left'
      : '$percent% · $distance $kilometers $left';

  String usedDistance(String distance) => isArabic
      ? '$used: $distance $kilometers'
      : 'Driven: $distance $kilometers';
  String intervalDistance(String distance) => isArabic
      ? 'تقدير الفاصل: $distance $kilometers'
      : 'Interval estimate: $distance $kilometers';
  String progressLabel(String percent) =>
      isArabic ? 'العمر المتبقي: $percent٪' : 'Remaining lifespan: $percent%';
  String dueBy(String date) =>
      isArabic ? 'موعد الاستحقاق: $date' : 'Due by $date';
  String get shelfLifeDueToday => isArabic ? 'مستحق اليوم' : 'Due today';
  String get shelfLifeExpired => isArabic ? 'منتهي الصلاحية' : 'Expired';

  String status(ServiceStatusKey status) => switch (status) {
    ServiceStatusKey.excellent => isArabic ? 'ممتاز' : 'Excellent',
    ServiceStatusKey.good => isArabic ? 'جيد' : 'Good',
    ServiceStatusKey.warning => isArabic ? 'تحذير' : 'Warning',
    ServiceStatusKey.replaceSoon =>
      isArabic ? 'استبدال قريباً' : 'Replace soon',
    ServiceStatusKey.replaceNow => isArabic ? 'استبدال الآن' : 'Replace now',
  };

  String condition(ServiceStatusKey status, String percent) => switch (status) {
    ServiceStatusKey.replaceNow =>
      isArabic ? 'حرج — $percent٪ مستهلك' : 'Critical — $percent% exhausted',
    ServiceStatusKey.replaceSoon =>
      isArabic ? 'قريباً — $percent٪ مستهلك' : 'Soon — $percent% exhausted',
    _ =>
      isArabic ? 'تحذير — $percent٪ مستهلك' : 'Warning — $percent% exhausted',
  };

  // --- Shared actions and settings labels ---

  String get saveAction => isArabic ? 'حفظ' : 'Save';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get done => isArabic ? 'تم' : 'Done';
  String get settingsTitle => isArabic ? 'الإعدادات' : 'Settings';
  String get appearanceSection => isArabic ? 'المظهر' : 'Appearance';
  String get garageSection => isArabic ? 'الجراش' : 'Garage';
  String get notificationsSection => isArabic ? 'الإشعارات' : 'Notifications';
  String get backupRestoreSection =>
      isArabic ? 'النسخ الاحتياطي والاستعادة' : 'Backup & restore';
  String get off => isArabic ? 'إيقاف' : 'Off';
  String get notSet => isArabic ? 'غير محدد' : 'Not set';
  String get theme => isArabic ? 'المظهر' : 'Theme';
  String get themeTelemetry => isArabic ? 'تيليمتري' : 'Telemetry';
  String get themeClassic => isArabic ? 'كلاسيك' : 'Classic';
  String get language => isArabic ? 'اللغة' : 'Language';
  String get languageEnglish => 'English';
  String get languageArabic => 'العربية';
  String get defaultVehicle =>
      isArabic ? 'المركبة الافتراضية' : 'Default vehicle';
  String defaultVehicleChangeTitle(String name) => isArabic
      ? 'تغيير المركبة الافتراضية إلى $name؟'
      : 'Change the default vehicle to $name?';
  String defaultVehicleChangeMessage(String name) => isArabic
      ? 'سيستخدم التطبيق $name لسياق لوحة التحكم عند الفتح، وستُعاد جدولة تذكيرات الصيانة لهذه المركبة.'
      : 'When the app opens, the dashboard will use $name and maintenance reminders will be rescheduled for it.';
  String get changeDefaultVehicle =>
      isArabic ? 'تغيير المركبة الافتراضية' : 'Change default vehicle';
  String get lastUsedVehicle =>
      isArabic ? 'آخر مركبة مستخدمة' : 'Last used vehicle';
  String get reminders => isArabic ? 'التذكيرات' : 'Reminders';
  String get maintenanceReminders =>
      isArabic ? 'تذكيرات الصيانة' : 'Maintenance reminders';
  String get enableReminders =>
      isArabic ? 'تفعيل التذكيرات' : 'Enable reminders';
  String get repeatUntilComplete => isArabic
      ? 'التكرار حتى اكتمال الصيانة'
      : 'Repeat until service is complete';
  String get day => isArabic ? 'اليوم' : 'Day';
  String get time => isArabic ? 'الوقت' : 'Time';
  String get remindersSaveFailed => isArabic
      ? 'تعذر حفظ إعدادات التذكيرات.'
      : 'Couldn’t save reminder settings.';

  String get remindersPermissionDenied => isArabic
      ? 'تم رفض إذن الإشعارات. فعّله من إعدادات النظام لتلقي التذكيرات.'
      : 'Notification permission is off. Enable it in system settings to receive reminders.';

  String get remindersSyncFailed => isArabic
      ? 'تعذر تحديث التذكيرات. حاول مرة أخرى.'
      : 'Couldn’t update reminders. Try again.';

  String get compactTireHealthCard =>
      isArabic ? 'بطاقة صحة الإطارات المختصرة' : 'Compact Tire Health card';
  String get compactTireHealthCardOn => isArabic ? 'تشغيل' : 'On';
  String get compactTireHealthCardOff => isArabic ? 'إيقاف' : 'Off';
  String get checkTirePrompt =>
      isArabic ? 'تحقق من هذا الإطار.' : 'Check this tire.';
  String get checkTire => isArabic ? 'تحقق من الإطار' : 'Check tire';
  String get ignore => isArabic ? 'تجاهل' : 'Ignore';

  // Backup, restore, and local-storage guidance (W10).

  String get backupAndRestore =>
      isArabic ? 'النسخ الاحتياطي والاستعادة' : 'Backup and restore';

  String get backupGuidance => isArabic
      ? 'يُخزَّن مرآبك على هذا الجهاز فقط من دون تشفير التطبيق. النسخة الاحتياطية نص عادي في الحافظة؛ تعامل معها كبيانات خاصة.'
      : 'Your garage is stored on this device only, without app-level encryption. Backups are plain text in the clipboard; treat them as private data.';

  String get localStorageTitle =>
      isArabic ? 'مكان تخزين بياناتك' : 'Where your data lives';

  String get localStorageGuidance => isArabic
      ? 'لا يُرسل مرآبك إلى أي خدمة. محفوظ في مساحة التطبيق الخاصة على هذا الجهاز، وتُحمّل بياناتك عند فتح التطبيق.'
      : 'Your garage is never sent to a service. It is kept in this device’s private app storage and loaded when you open the app.';

  String get copyBackup => isArabic ? 'نسخ نسخة احتياطية' : 'Copy backup';

  String get backupCopied => isArabic
      ? 'تم نسخ النسخة الاحتياطية إلى الحافظة.'
      : 'Backup copied to the clipboard.';

  String get backupFailed => isArabic
      ? 'تعذر إنشاء نسخة احتياطية. حاول مرة أخرى.'
      : 'Couldn’t copy a backup. Try again.';

  String get restoreBackup => isArabic ? 'استعادة نسخة' : 'Restore backup';

  String get clipboardEmptyBackup => isArabic
      ? 'لا توجد نسخة احتياطية في الحافظة.'
      : 'No backup was found on the clipboard.';

  String get restoreConfirmTitle =>
      isArabic ? 'استبدال المرآب الحالي؟' : 'Replace the current garage?';

  String get restoreConfirmMessage => isArabic
      ? 'سيستبدل هذا كل ما هو محفوظ على هذا الجهاز بمحتوى النسخة الاحتياطية.'
      : 'This replaces everything stored on this device with the contents of the backup.';

  String get restoreConfirmAction => isArabic ? 'استبدال' : 'Replace';

  String get restoreComplete =>
      isArabic ? 'تمت استعادة المرآب.' : 'Garage restored.';

  String get restoreFailed => isArabic
      ? 'هذه النسخة غير صالحة للمرآب. لم يتم تغيير شيء.'
      : 'That backup isn’t valid for this app. Nothing was changed.';

  String get restoreNotGarageBackup => isArabic
      ? 'هذه ليست نسخة احتياطية من هذا التطبيق.'
      : 'That isn’t a GearTracker backup.';

  String get unsupportedBackupVersion => isArabic
      ? 'هذه النسخة من إصدار أحدث من التطبيق.'
      : 'That backup comes from a newer version of the app.';

  String get closeAction => isArabic ? 'إغلاق' : 'Close';

  String weekdayName(int weekday) => switch (weekday) {
    DateTime.monday => isArabic ? 'الاثنين' : 'Monday',
    DateTime.tuesday => isArabic ? 'الثلاثاء' : 'Tuesday',
    DateTime.wednesday => isArabic ? 'الأربعاء' : 'Wednesday',
    DateTime.thursday => isArabic ? 'الخميس' : 'Thursday',
    DateTime.friday => isArabic ? 'الجمعة' : 'Friday',
    DateTime.saturday => isArabic ? 'السبت' : 'Saturday',
    _ => isArabic ? 'الأحد' : 'Sunday',
  };

  String reminderScheduleSummary(String weekday, String timeOfDay) =>
      isArabic ? '$weekday، $timeOfDay' : '$weekday, $timeOfDay';

  // --- Dashboard messages ---

  String get tireHealthAdded =>
      isArabic ? 'تمت إضافة حالة الإطارات' : 'Tire health added';
  String get tireHealthRemoved =>
      isArabic ? 'تمت إزالة حالة الإطارات' : 'Tire health removed';
  String serviceSaved(String name) => isArabic ? 'تم حفظ $name' : '$name saved';
  String serviceMarkedServiced(String name) =>
      isArabic ? 'تم تسجيل إتمام صيانة $name' : '$name marked serviced';
  String serviceDeleted(String name) =>
      isArabic ? 'تم حذف $name' : '$name deleted';
  String get deleteServiceQuestion =>
      isArabic ? 'حذف الصيانة؟' : 'Delete service?';
  String removeServiceFromVehicle(String name) => isArabic
      ? 'إزالة $name من هذه المركبة؟'
      : 'Remove $name from this vehicle?';
  String removeServiceAndHistoryFromVehicle(String name) => isArabic
      ? 'إزالة $name وسجل صيانته من هذه المركبة؟'
      : 'Remove $name and its service history from this vehicle?';
  String removeService(String name) =>
      isArabic ? 'إزالة $name؟' : 'Remove $name?';
  String get addServiceTitle => isArabic ? 'إضافة صيانة' : 'Add Service';
  String get serviceCardActionsTitle =>
      isArabic ? 'إجراءات الصيانة' : 'Service actions';
  String serviceCardActionsMessage(String name) => isArabic
      ? 'ماذا تريد أن تفعل مع $name؟'
      : 'What would you like to do with $name?';
  String get serviceActionMarkServiced =>
      isArabic ? 'تسجيل إتمام الصيانة' : 'Mark serviced';
  String get lastServicedLabel => isArabic ? 'آخر صيانة' : 'Last serviced';
  String get trackingSummaryLabel => isArabic ? 'التتبع' : 'Tracking';
  String get trackingMileageSummary => isArabic ? 'المسافة' : 'Mileage';
  String get trackingTimeSummary => isArabic ? 'الوقت' : 'Time';
  String get trackingBothSummary =>
      isArabic ? 'المسافة والوقت' : 'Mileage and time';
  String get noServiceHistoryShort =>
      isArabic ? 'لا توجد صيانة مسجلة' : 'No service recorded';
  String get changeIcon => isArabic ? 'تغيير الأيقونة' : 'Change icon';
  String serviceIconLabel(String iconKey) =>
      servicePresetName(iconKey, iconKey);
  String get showGuidance => isArabic ? 'إظهار الإرشادات' : 'Show guidance';
  String get showGuidanceOn => isArabic ? 'الإرشادات مفعّلة' : 'Guidance on';
  String get showGuidanceOff => isArabic ? 'الإرشادات متوقفة' : 'Guidance off';
  String get discardChangesQuestion =>
      isArabic ? 'تجاهل التغييرات؟' : 'Discard changes?';
  String get discardChangesMessage => isArabic
      ? 'ستفقد التغييرات التي أجريتها على هذه الصيانة.'
      : 'Your changes to this service will be lost.';
  String get discard => isArabic ? 'تجاهل' : 'Discard';
  String get timePresetOneYear => isArabic ? 'سنة واحدة' : '1 year';
  String get timePresetTwoYears => isArabic ? 'سنتان' : '2 years';
  String get timePresetThreeYears => isArabic ? '3 سنوات' : '3 years';
  String get timePresetFiveYears => isArabic ? '5 سنوات' : '5 years';

  // --- Add-service screen ---

  String get customService =>
      isArabic ? 'إنشاء صيانة مخصصة' : 'Create custom service';
  String get tireHealthTrackedSubtitle =>
      isArabic ? 'تتبع حسب الموضع' : 'Tracked by position';
  String get tireHealthAddSubtitle =>
      isArabic ? 'إضافة تتبع رباعي المواضع' : 'Add four-position tracking';
  String get deleteTireHealthQuestion =>
      isArabic ? 'حذف حالة الإطارات؟' : 'Delete Tire health?';
  String get tireHealthDataLostMessage => isArabic
      ? 'ستُفقد بيانات الإطارات الرباعية لهذه المركبة.'
      : 'The four-position tire data for this vehicle will be lost.';
  String deleteServiceWithName(String name) =>
      isArabic ? 'حذف $name؟' : 'Delete $name?';
  String get serviceDataLostMessage => isArabic
      ? 'ستفقد هذه الصيانة وبياناتها المحفوظة.'
      : 'This service and its saved data will be lost.';
  String get chooseIcon => isArabic ? 'اختر أيقونة' : 'Choose an icon';
  String get chooseIconInstruction => isArabic
      ? 'اختر أيقونة السيارات الأنسب لهذه الصيانة.'
      : 'Pick the automotive icon that best fits this service.';
  String get useIconHint => isArabic
      ? 'استخدم هذه الأيقونة لصيانة مخصصة'
      : 'Use this icon for your custom service';
  String get useAutomaticIcon =>
      isArabic ? 'استخدم الأيقونة التلقائية' : 'Use automatic icon';

  // --- Service form ---

  String get selectedServiceIcon =>
      isArabic ? 'أيقونة الصيانة المحددة' : 'Selected service icon';
  String get schedule => isArabic ? 'الجدولة' : 'Schedule';
  String get review => isArabic ? 'مراجعة' : 'Review';
  String get installKm => isArabic ? 'كم التركيب' : 'Install KM';
  String get installedOn => isArabic ? 'تاريخ التركيب' : 'Installed on';
  String get repeatEvery => isArabic ? 'التكرار كل' : 'Repeat every';
  String get enterPositiveShelfLife => isArabic
      ? 'أدخل مدة أكبر من 0 شهر'
      : 'Enter a duration greater than 0 months';
  String get addDuplicateServiceQuestion =>
      isArabic ? 'إضافة صيانة مكررة؟' : 'Add duplicate service?';
  String get duplicateServiceMessage => isArabic
      ? 'توجد صيانة بهذا الاسم على اللوحة الرئيسية بالفعل. يمكنك إضافة أخرى.'
      : 'A service with this name is already on the dashboard. You can still add another one.';
  String get addAnyway => isArabic ? 'إضافة على أي حال' : 'Add anyway';
  String get trackServiceBy =>
      isArabic ? 'تتبع الصيانة بواسطة' : 'Track service by';
  String get trackingModeMileage => isArabic ? 'المسافة' : 'Mileage';
  String get trackingModeTime => isArabic ? 'الوقت' : 'Time';
  String get trackingModeBoth => isArabic ? 'كلاهما' : 'Both';
  String get mileageDescription =>
      isArabic ? 'تُستحق بعد قطع المسافة.' : 'Due after distance driven.';
  String get timeDescription =>
      isArabic ? 'عمر زمني مثل البطارية.' : 'Age-based, like a battery.';
  String get bothDescription =>
      isArabic ? 'تُستحق عند بلوغ أي حد.' : 'Due when either limit is reached.';
  String get enterValidInstallKm =>
      isArabic ? 'أدخل قراءة تركيب صالحة' : 'Enter a valid install km';
  String get installKmCannotExceedCurrent => isArabic
      ? 'لا يمكن أن تتجاوز قراءة التركيب القراءة الحالية'
      : 'Install km cannot exceed current km';
  String get servicePreview => isArabic ? 'معاينة الصيانة' : 'Service preview';
  String get previewInstalled => isArabic ? 'التثبيت' : 'Installed';
  String get previewEnterInstallKm =>
      isArabic ? 'أدخل كم التركيب' : 'Enter install km';
  String get previewMileage => isArabic ? 'المسافة' : 'Mileage';
  String get previewEnterInterval =>
      isArabic ? 'أدخل الفترة' : 'Enter interval';
  String get previewEnterShelfLife =>
      isArabic ? 'أدخل العمر الزمني' : 'Enter shelf life';
  String previewValueKm(String value) =>
      isArabic ? '$value $kilometers' : '$value $kilometers';
  String previewValueMonths(String value) =>
      isArabic ? '$value $months' : '$value $months';

  // --- Edit-service screen ---

  String get editServiceTitle => isArabic ? 'تعديل الصيانة' : 'Edit Service';
  String viewHistory(String name) =>
      isArabic ? 'عرض سجل $name' : 'View $name history';
  String markServiceServiced(String name) =>
      isArabic ? 'تسجيل إتمام صيانة $name' : 'Mark $name serviced';
  String get completedOn => isArabic ? 'اكتمل في' : 'Completed on';
  String get completedKmLabel => isArabic ? 'كم الإكمال' : 'Completed KM';
  String completionKmHelperText(String minimum, String maximum) => isArabic
      ? 'يجب أن يكون بين $minimum–$maximum كم.'
      : 'Must be $minimum–$maximum km.';
  String enterCompletionKmRange(String minimum, String maximum) => isArabic
      ? 'أدخل قراءة بين $minimum و $maximum كم.'
      : 'Enter a km from $minimum to $maximum.';
  String get confirmService => isArabic ? 'تأكيد الصيانة' : 'Confirm service';
  String get saveChanges => isArabic ? 'حفظ التغييرات' : 'Save changes';
  String get deleteService => isArabic ? 'حذف الصيانة' : 'Delete service';

  // --- History ---

  String get serviceHistory => isArabic ? 'سجل الصيانة' : 'Service history';
  String historyTitle(String name) => isArabic ? 'سجل $name' : '$name history';
  String get noServiceHistoryYet =>
      isArabic ? 'لا يوجد سجل صيانة بعد' : 'No service history yet';
  String get completedServiceUpdatesWillAppear => isArabic
      ? 'ستظهر تحديثات الصيانة المكتملة هنا.'
      : 'Completed service updates will appear here.';
  String completedServiceUpdatesWillAppearFor(String name) => isArabic
      ? 'ستظهر تحديثات صيانة $name المكتملة هنا.'
      : 'Completed $name updates will appear here.';
  String completedAtValue(String km) =>
      isArabic ? 'اكتمل عند $km $kilometers' : 'completed at $km $kilometers';
  String nextIntervalValue(String km) => isArabic
      ? 'الفترة التالية $km $kilometers'
      : 'next interval $km $kilometers';
  String historyNote(String note) => isArabic ? 'ملاحظة: $note' : 'Note: $note';
  String onDate(String date) => isArabic ? 'في $date' : 'on $date';
  String completedAtKm(String km) =>
      isArabic ? 'اكتمل عند $km $kilometers' : 'Completed at $km $kilometers';
  String completedOnDate(String date) =>
      isArabic ? 'اكتمل $date' : 'Completed $date';
  String nextIntervalLine(String km) => isArabic
      ? 'الفترة التالية: $km $kilometers'
      : 'Next interval: $km $kilometers';

  // --- Odometer card ---

  String get liveOdometerReading =>
      isArabic ? 'عداد المسافة الحالي' : 'Current odometer';
  String lastUpdatedAt(String date, String time) =>
      isArabic ? 'آخر تحديث: $date، $time' : 'Last updated: $date, $time';
  String get lastUpdatedUnknown =>
      isArabic ? 'آخر تحديث: غير متاح بعد' : 'Last updated: Not available yet';
  String get hundredThousands => isArabic ? 'مئات الآلاف' : 'Hundred thousands';
  String get tenThousands => isArabic ? 'عشرات الآلاف' : 'Ten thousands';
  String get thousands => isArabic ? 'آلاف' : 'Thousands';
  String get hundreds => isArabic ? 'مئات' : 'Hundreds';
  String get tens => isArabic ? 'عشرات' : 'Tens';
  String get ones => isArabic ? 'آحاد' : 'Ones';
  String digitLabel(String? place, String value) => place == null
      ? (isArabic
            ? 'رقم، القيمة الحالية $value'
            : 'Digit, current value $value')
      : (isArabic
            ? '$place، الرقم، القيمة الحالية $value'
            : '$place digit, current value $value');

  // --- Service-picker card ---

  String selectedLabel(String title) =>
      isArabic ? '$title، محدد' : '$title, selected';
  String get alreadySelectedHint =>
      isArabic ? 'محدد بالفعل' : 'Already selected';
  String get openServiceDetailsHint =>
      isArabic ? 'فتح نموذج تفاصيل الصيانة' : 'Open service details form';

  // --- Service-health card ---

  String checkOverdueBy(String days) =>
      isArabic ? 'متأخر $days أيام' : 'Check overdue by $days days';
  String checkIn(String days) =>
      isArabic ? 'افحص خلال $days أيام' : 'Check in $days days';
  String get timeBased => isArabic ? 'عمر زمني' : 'time-based';
  String get intervalEstimateNote => isArabic
      ? 'تقديرات الفواصل إرشادية. اتبع جدول صيانة مركبتك عند الحاجة.'
      : 'Interval estimates are guidance. Follow your vehicle maintenance schedule when needed.';
  String get showDetails => isArabic ? 'إظهار التفاصيل' : 'Show details';
  String get hideDetails => isArabic ? 'إخفاء التفاصيل' : 'Hide details';
  String get optionalDetails =>
      isArabic ? 'تفاصيل اختيارية' : 'Optional details';
  String get addNote => isArabic ? 'إضافة ملاحظة' : 'Add a note';
  String get scheduleDetails =>
      isArabic ? 'تفاصيل الجدولة' : 'Schedule details';
  String get needsAttention =>
      isArabic ? 'يحتاج إلى اهتمام' : 'Needs attention';
  String needsAttentionCount(int count) => isArabic
      ? '$count عنصر يحتاج إلى اهتمام'
      : '$count item${count == 1 ? '' : 's'} need${count == 1 ? 's' : ''} attention';
  String get reviewNextAction => isArabic ? 'راجع التالي' : 'Review next';

  // --- Vehicle screens ---

  String get yourVehicles => isArabic ? 'مركباتك' : 'Your vehicles';
  String get createCleanProfile =>
      isArabic ? 'إنشاء ملف نظيف' : 'Create a clean profile';
  String get editVehicle => isArabic ? 'تعديل المركبة' : 'Edit vehicle';
  String get year => isArabic ? 'السنة' : 'Year';
  String get yearHint => isArabic ? '2022' : '2022';
  String get enterModelYear =>
      isArabic ? 'أدخل سنة الطراز' : 'Enter the model year';
  String get enterYearBetween => isArabic
      ? 'أدخل سنة بين 1900 و 2100'
      : 'Enter a year between 1900 and 2100';
  String get makeOptional => isArabic ? 'الصانع (اختياري)' : 'Make (optional)';
  String get makeHint => isArabic ? 'Volkswagen' : 'Volkswagen';
  String get model => isArabic ? 'الطراز' : 'Model';
  String get modelHint => isArabic ? 'Golf GTI' : 'Golf GTI';
  String get enterModel => isArabic ? 'أدخل الطراز' : 'Enter the model';
  String get currentOdometerField =>
      isArabic ? 'عداد المسافة الحالي (كم)' : 'Current odometer (km)';
  String get odometerHint => isArabic ? '74850' : '74850';
  String get enterCurrentOdometer =>
      isArabic ? 'أدخل عداد المسافة الحالي' : 'Enter the current odometer';
  String enterOdometerRange(String minimum, String maximum) => isArabic
      ? 'أدخل قيمة بين $minimum و $maximum'
      : 'Enter a value between $minimum and $maximum';
  String get selectVehicle => isArabic ? 'اختيار مركبة' : 'Select vehicle';
  String get noVehiclesYet =>
      isArabic ? 'لم تتم إضافة مركبات بعد' : 'No vehicles added yet';

  // --- Discoverability (card actions, undo, preset grouping, search) ---

  String get serviceMenuTooltip =>
      isArabic ? 'إجراءات الصيانة' : 'Service actions';
  String get vehicleMenuTooltip =>
      isArabic ? 'إجراءات المركبة' : 'Vehicle actions';
  String get removeAction => isArabic ? 'إزالة' : 'Remove';
  String get undoAction => isArabic ? 'تراجع' : 'Undo';
  String serviceRestored(String name) =>
      isArabic ? 'تمت استعادة $name' : '$name restored';
  String get searchServicesHint =>
      isArabic ? 'ابحث عن الصيانة' : 'Search services';
  String get noServicesMatch =>
      isArabic ? 'لا توجد صيانة مطابقة' : 'No matching services';
  String get presetGroupMaintenance =>
      isArabic ? 'الصيانة الدورية' : 'Routine maintenance';
  String get presetGroupBrakesAndTires =>
      isArabic ? 'الفرامل والإطارات' : 'Brakes & tires';
  String get presetGroupEngineAndDrivetrain =>
      isArabic ? 'المحرك وناقل الحركة' : 'Engine & drivetrain';
  String get presetGroupElectricalAndClimate =>
      isArabic ? 'الكهرباء والتكييف' : 'Electrical & climate';
  String get presetGroupEngine => isArabic ? 'المحرك' : 'Engine';
  String get presetGroupFluids =>
      isArabic ? 'السوائل والفلاتر' : 'Fluids & filters';
  String get presetGroupElectrical => isArabic ? 'الكهرباء' : 'Electrical';
  String get presetGroupOther => isArabic ? 'خدمات أخرى' : 'Other';

  String servicePresetName(String iconKey, String fallback) =>
      switch (iconKey) {
        'oil' => isArabic ? 'زيت المحرك' : 'Engine oil',
        'oil_filter' => isArabic ? 'فلتر الزيت' : 'Oil filter',
        'air_filter' => isArabic ? 'فلتر الهواء' : 'Air filter',
        'cabin_filter' => isArabic ? 'فلتر المقصورة' : 'Cabin filter',
        'brake_pads' => isArabic ? 'تيل الفرامل' : 'Brake pads',
        'brake_fluid' => isArabic ? 'سائل الفرامل' : 'Brake fluid',
        'tires' =>
          isArabic ? 'تدوير ومحاذاة الإطارات' : 'Tire rotation and alignment',
        'tire_health' => isArabic ? 'حالة الإطارات' : 'Tire health',
        'battery' => isArabic ? 'البطارية' : 'Battery',
        'spark_plugs' => isArabic ? 'شمعات الإشعال' : 'Spark plugs',
        'coolant' => isArabic ? 'سائل التبريد' : 'Coolant',
        'transmission_fluid' =>
          isArabic ? 'سائل ناقل الحركة' : 'Transmission fluid',
        'power_steering' => isArabic ? 'سائل التوجيه' : 'Power steering fluid',
        'timing_belt' =>
          isArabic ? 'فحص سير/سلسلة التوقيت' : 'Timing belt / chain inspection',
        'drive_belts' => isArabic ? 'سيور الحركة' : 'Drive belts',
        'wipers' => isArabic ? 'شفرات المساحات' : 'Wiper blades',
        'suspension' =>
          isArabic ? 'فحص التعليق والممتصات' : 'Suspension / shocks inspection',
        'fuel_filter' => isArabic ? 'فلتر الوقود' : 'Fuel filter',
        'ac' => isArabic ? 'صيانة التكييف' : 'AC service',
        'maintenance' => isArabic ? 'صيانة عامة' : 'General maintenance',
        _ => fallback,
      };

  String servicePresetDescription(String iconKey) => switch (iconKey) {
    'oil' =>
      isArabic ? 'يحافظ على تزييت المحرك' : 'Keeps the engine lubricated',
    'oil_filter' =>
      isArabic ? 'ينقّي الزيت من الشوائب' : 'Removes contaminants from the oil',
    'air_filter' =>
      isArabic
          ? 'ينقّي الهواء الداخل للمحرك'
          : 'Cleans air entering the engine',
    'cabin_filter' =>
      isArabic ? 'ينقّي الهواء داخل المقصورة' : 'Cleans air inside the cabin',
    'brake_pads' =>
      isArabic ? 'يتابع تآكل بطانات الفرامل' : 'Tracks brake pad wear',
    'brake_fluid' =>
      isArabic ? 'يتابع سائل نظام الفرامل' : 'Tracks the brake system fluid',
    'tires' =>
      isArabic ? 'يتابع التدوير والمحاذاة' : 'Tracks rotation and alignment',
    'tire_health' =>
      isArabic
          ? 'يتابع عمر الإطارات الأربعة'
          : 'Tracks the life of all four tires',
    'battery' => isArabic ? 'يتابع حالة البطارية' : 'Tracks battery condition',
    'spark_plugs' =>
      isArabic ? 'يتابع عمر شمعات الإشعال' : 'Tracks spark plug life',
    'coolant' => isArabic ? 'يتابع سائل تبريد المحرك' : 'Tracks engine coolant',
    'transmission_fluid' =>
      isArabic ? 'يتابع سائل ناقل الحركة' : 'Tracks transmission fluid',
    'power_steering' =>
      isArabic ? 'يتابع سائل التوجيه' : 'Tracks power steering fluid',
    'timing_belt' =>
      isArabic
          ? 'يتابع سير أو سلسلة التوقيت'
          : 'Tracks timing belt or chain service',
    'drive_belts' =>
      isArabic ? 'يتابع حالة سيور الحركة' : 'Tracks drive belt condition',
    'wipers' =>
      isArabic ? 'يتابع عمر شفرات المساحات' : 'Tracks wiper blade life',
    'suspension' =>
      isArabic
          ? 'يتابع فحص التعليق والممتصات'
          : 'Tracks suspension and shock checks',
    'fuel_filter' =>
      isArabic
          ? 'ينقّي الوقود قبل وصوله للمحرك'
          : 'Cleans fuel before it reaches the engine',
    'ac' =>
      isArabic ? 'يتابع صيانة نظام التكييف' : 'Tracks air-conditioning service',
    'maintenance' =>
      isArabic ? 'خدمة مخصصة حسب احتياجك' : 'A service tailored to your needs',
    _ => '',
  };

  String serviceCardName({
    required String id,
    required String iconKey,
    required String fallback,
  }) {
    if (!isArabic) return fallback;
    if (id.startsWith('demo-')) {
      return switch (id) {
        'demo-engine-oil' => 'زيت المحرك',
        'demo-brake-pads' => 'تيل الفرامل',
        'demo-air-filter' => 'فلتر الهواء',
        'demo-battery' => 'فحص البطارية',
        'demo-timing-belt' => 'سير التوقيت',
        'demo-oil-filter' => 'فلتر الزيت',
        'demo-cabin-filter' => 'فلتر المقصورة',
        'demo-brake-fluid' => 'سائل الفرامل',
        'demo-tire-rotation' => 'تدوير الإطارات',
        'demo-spark-plugs' => 'شمعات الإشعال',
        'demo-coolant' => 'سائل التبريد',
        'demo-transmission-fluid' => 'سائل ناقل الحركة',
        'demo-power-steering' => 'سائل التوجيه',
        'demo-drive-belts' => 'سيور الحركة',
        'demo-wipers' => 'شفرات المساحات',
        'demo-suspension' => 'فحص التعليق',
        'demo-fuel-filter' => 'فلتر الوقود',
        'demo-ac-service' => 'صيانة التكييف',
        'demo-coolant-change-now' => 'غيّر سائل التبريد الآن',
        'demo-general-maintenance' => 'صيانة عامة',
        _ => servicePresetName(iconKey, fallback),
      };
    }
    return switch ((iconKey, fallback.toLowerCase())) {
      ('oil', 'engine oil') => 'زيت المحرك',
      ('oil_filter', 'oil filter') => 'فلتر الزيت',
      ('air_filter', 'air filter') => 'فلتر الهواء',
      ('cabin_filter', 'cabin filter') => 'فلتر المقصورة',
      ('brake_pads', 'brake pads') => 'تيل الفرامل',
      ('brake_fluid', 'brake fluid') => 'سائل الفرامل',
      ('tires', 'tire rotation and alignment') => 'تدوير ومحاذاة الإطارات',
      ('battery', 'battery') => 'البطارية',
      ('spark_plugs', 'spark plugs') => 'شمعات الإشعال',
      ('coolant', 'coolant') => 'سائل التبريد',
      ('transmission_fluid', 'transmission fluid') => 'سائل ناقل الحركة',
      ('power_steering', 'power steering fluid') => 'سائل التوجيه',
      ('timing_belt', 'timing belt / chain inspection') =>
        'فحص سير/سلسلة التوقيت',
      ('drive_belts', 'drive belts') => 'سيور الحركة',
      ('wipers', 'wiper blades') => 'شفرات المساحات',
      ('suspension', 'suspension / shocks inspection') =>
        'فحص التعليق والممتصات',
      ('fuel_filter', 'fuel filter') => 'فلتر الوقود',
      ('ac', 'ac service') => 'صيانة التكييف',
      ('maintenance', 'general maintenance') => 'صيانة عامة',
      _ => fallback,
    };
  }

  String serviceCardNote({required String id, required String fallback}) {
    if (!id.startsWith('demo-') || !isArabic) return fallback;
    return switch (id) {
      'demo-engine-oil' => 'زيت صناعي بالكامل 5W-30',
      'demo-brake-pads' => 'فحص المحور الأمامي',
      'demo-air-filter' => 'افحص الفلتر وبيت سحب الهواء',
      'demo-battery' => 'افحص الأقطاب ومستوى الشحن',
      'demo-timing-belt' => 'الاستبدال حسب المسافة أو التاريخ',
      'demo-oil-filter' => 'استبدله مع صيانة زيت المحرك',
      'demo-cabin-filter' => 'استبدله للحفاظ على هواء المقصورة',
      'demo-brake-fluid' => 'غيّر السائل وافحص مستوى الرطوبة',
      'demo-tire-rotation' => 'دوّر الإطارات وافحص المحاذاة',
      'demo-spark-plugs' => 'افحص الفجوة وأداء الإشعال',
      'demo-coolant' => 'افحص المستوى واللون والحماية من التجمد',
      'demo-transmission-fluid' => 'افحص المستوى وجودة تبديل السرعات',
      'demo-power-steering' => 'افحص مستوى السائل والتسربات',
      'demo-drive-belts' => 'افحص الشد والتشققات والتآكل',
      'demo-wipers' => 'استبدلها عند ظهور الخطوط أو الاهتزاز',
      'demo-suspension' => 'افحص المساعدين والقواعد والجلب',
      'demo-fuel-filter' => 'استبدله وافحص خطوط الوقود',
      'demo-ac-service' => 'افحص أداء التبريد وغاز التكييف',
      'demo-coolant-change-now' => 'حان وقت الاستبدال',
      'demo-general-maintenance' => 'فحص موسمي وفحص السوائل',
      _ => fallback,
    };
  }

  String get customServiceDescription =>
      isArabic ? 'خدمة مخصصة حسب احتياجك' : 'A service tailored to your needs';
  String get tireHealthDescription => servicePresetDescription('tire_health');
}

enum ServiceStatusKey { excellent, good, warning, replaceSoon, replaceNow }

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
