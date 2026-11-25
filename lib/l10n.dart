part of 'main.dart';

// ═════════════════════════ اللغة (عربي / English) ═════════════════════════
//
// الاستخدام: tr('نص عربي') بيرجّع النص نفسه لو اللغة عربي، والترجمة الإنجليزي
// لو اللغة English. أي نص مالوش ترجمة في الجدول تحت بيفضل بالعربي.
// لإضافة ترجمة جديدة: ضيف سطر في _kEn وغلّف النص في الكود بـ tr(...).

String tr(String ar) {
  if (AppSettings.instance.lang != 'en') return ar;
  return _kEn[ar] ?? ar;
}

/// نفس tr بس للنصوص اللي فيها قيم: القالب فيه {0} {1} والقيم في args.
String trf(String ar, List<Object?> args) {
  var s = AppSettings.instance.lang != 'en' ? ar : (_kEn[ar] ?? ar);
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

const Map<String, String> _kEn = {
  // الشاشة الافتتاحية واختيار المصنع
  'رصد المخالفات': 'Violation Monitoring',
  'رصد المخالفات البيئية': 'Environmental Violation Monitoring',
  'معًا للحفاظ على البيئة': 'Together for the environment',
  'اختر مصنعك': 'Choose your factory',
  'اضغط على شعار مصنعك لتسجيل الدخول': 'Tap your factory logo to sign in',
  'لسه مفيش مصانع. المدير يدخل ويضيفها.':
      'No factories yet. The admin must sign in and add them.',
  'إعادة المحاولة': 'Retry',
  'دخول المدير العام': 'General manager sign-in',
  'المدير العام': 'General manager',
  // تسجيل الدخول
  'اسم المستخدم': 'Username',
  'كلمة المرور': 'Password',
  'دخول': 'Sign in',
  'دخول بالبصمة': 'Sign in with fingerprint',
  'ادخل بالبصمة': 'Use your fingerprint to sign in',
  'تفعيل الدخول بالبصمة؟': 'Enable fingerprint sign-in?',
  'هتدخل المرة الجاية بالبصمة بدل اسم المستخدم وكلمة المرور.':
      'Next time you can sign in with your fingerprint instead of typing your username and password.',
  'مش دلوقتي': 'Not now',
  'تفعيل': 'Enable',
  'البصمة مش متاحة أو مش متسجلة على الجهاز':
      'Fingerprint is not available or not set up on this device',
  'تعذّر الدخول بالبصمة. ادخل بالاسم والباسورد':
      'Fingerprint sign-in failed. Please sign in with your password.',
  // رسائل تسجيل الدخول
  'رابط السيرفر مش متظبط في التطبيق': 'The server URL is not configured in the app',
  'اكتب اسم المستخدم والباسورد': 'Enter your username and password',
  'اسم المستخدم أو الباسورد غلط': 'Wrong username or password',
  'الحساب ده غير مفعّل. كلّم المدير':
      'This account is not activated. Contact the admin',
  'الحساب مش مربوط بمصنع. كلّم المدير':
      'This account is not linked to a factory. Contact the admin',
  'الحساب ده مش تابع للمصنع اللي اخترته':
      'This account does not belong to the factory you selected',
  'مقدرناش نوصل للسيرفر. راجع الإنترنت':
      'Could not reach the server. Check your internet connection',
  // الإعدادات
  'التحليلات': 'Analytics',
  'أخضر مائي': 'Aqua green',
  'أخضر زيتي': 'Olive green',
  'ليموني': 'Lime',
  'أزرق سماوي': 'Sky blue',
  'كحلي': 'Navy',
  'نيلي': 'Indigo',
  'أرجواني': 'Magenta',
  'وردي غامق': 'Deep pink',
  'وردي': 'Pink',
  'برتقالي فاتح': 'Light orange',
  'أصفر': 'Yellow',
  'عنبري': 'Amber',
  'بني فاتح': 'Light brown',
  'رمادي مزرق': 'Blue grey',
  'أسود': 'Black',
  'ذهبي': 'Gold',
  'لون مخصص': 'Custom color',
  'درجة اللون': 'Hue',
  'التشبّع': 'Saturation',
  'الإضاءة': 'Brightness',
  'تم': 'Done',
  'تعذّر اختيار الصورة': 'Could not pick the photo',
  'التقاط صورة': 'Take a photo',
  'حذف الصورة': 'Remove photo',
  'الإعدادات': 'Settings',
  'حسابي': 'My account',
  'تسجيل الخروج': 'Sign out',
  'اللغة': 'Language',
  'العربية': 'العربية',
  'البصمة': 'Fingerprint',
  'مسح بيانات الدخول بالبصمة': 'Remove saved fingerprint sign-in',
  'تم مسح بيانات الدخول بالبصمة': 'Fingerprint sign-in removed',
  'المظهر': 'Appearance',
  'نمط الألوان': 'Color mode',
  'تلقائي': 'Auto',
  'فاتح': 'Light',
  'داكن': 'Dark',
  'لون التطبيق': 'App color',

  // ─── المرحلة 2: باقي الشاشات ───
  'جديد':
      'New',
  'رقم {0}':
      'No. {0}',
  'تصوير بالكاميرا':
      'Take a photo',
  'اختيار من المعرض':
      'Choose from gallery',
  'الاسم':
      'Name',
  'إلغاء':
      'Cancel',
  'إضافة':
      'Add',
  'إضافة خيار جديد':
      'Add a new option',
  'خيار جديد':
      'New option',
  'أخضر':
      'Green',
  'أزرق':
      'Blue',
  'تركواز':
      'Teal',
  'برتقالي':
      'Orange',
  'بنفسجي':
      'Purple',
  'أحمر':
      'Red',
  'بني':
      'Brown',
  'رمادي':
      'Gray',
  'مفيش صلاحية في {0}. راجع المفتاح وسكربت الإعداد':
      'No permission for {0}. Check the key and the setup script',
  'مش لاقي الجدول أو مخزن الصور. شغّل سكربت الإعداد في Supabase':
      'Table or photo storage not found. Run the setup script in Supabase',
  'فشل {0} (كود {1})':
      '{0} failed (code {1})',
  'الاتصال تمام لكن جدول reports مش موجود. شغّل سكربت الإعداد في Supabase':
      'Connected, but the reports table does not exist. Run the setup script in Supabase',
  'المفتاح غلط أو مفيش صلاحية ({0})':
      'Wrong key or no permission ({0})',
  'فشل الاتصال (كود {0})':
      'Connection failed (code {0})',
  'مقدرناش نوصل للسيرفر. راجع الرابط والإنترنت':
      'Could not reach the server. Check the URL and your internet connection',
  'المزامنة شغالة بالفعل':
      'Sync is already running',
  'انتهت الجلسة، سجّل الدخول من جديد':
      'Session expired. Please sign in again',
  'مفيش اتصال بالإنترنت أو السيرفر مش بيرد':
      'No internet connection or the server is not responding',
  'رفع الصورة':
      'uploading the photo',
  'إرسال البلاغ':
      'sending the report',
  'تحديث البلاغ':
      'updating the report',
  'تحميل البلاغات':
      'loading reports',
  'كل حاجة محدّثة ✅':
      'Everything is up to date ✅',
  'تمت المزامنة ✅  أُرسل {0} • وصل {1}':
      'Synced ✅  Sent {0} • Received {1}',
  'فشلت المزامنة: {0}':
      'Sync failed: {0}',
  'فشلت المزامنة، راجع الإنترنت':
      'Sync failed. Check your internet connection',
  'تسجيل مخالفة':
      'Report violation',
  'السجل':
      'Records',
  'الخريطة':
      'Map',
  'نوع المخالفة':
      'Violation type',
  'الكل':
      'All',
  'المكان':
      'Location',
  'مسح الفلتر':
      'Clear filter',
  'تطبيق':
      'Apply',
  'مزامنة مع السيرفر':
      'Sync with server',
  'تصدير':
      'Export',
  'تصدير PDF (بالصور)':
      'Export PDF (with photos)',
  'تصدير Excel / CSV':
      'Export Excel / CSV',
  'الإجمالي':
      'Total',
  'جاري':
      'In progress',
  'فلترة':
      'Filter',
  'مفيش بلاغات لسه.\nاضغط "تسجيل مخالفة" وصوّر أي مخلفات في الموقع.':
      'No reports yet.\nTap "Report violation" and photograph any waste on site.',
  'مفيش بلاغات بالفلتر ده.':
      'No reports match this filter.',
  'بدون وصف':
      'No description',
  'متأخر':
      'Overdue',
  'اكتب رابط السيرفر والمفتاح الأول':
      'Enter the server URL and key first',
  'تم الاتصال بالسيرفر بنجاح ✅':
      'Connected to the server successfully ✅',
  'تم نسخ السكربت. الزقه في Supabase ثم Run':
      'Script copied. Paste it in Supabase and press Run',
  'لسه ماتمتش مزامنة':
      'Not synced yet',
  'آخر مزامنة: {0}  {1}:{2}':
      'Last sync: {0}  {1}:{2}',
  'مدير عام • {0}':
      'General manager • {0}',
  'مبلّغ • {0}':
      'Reporter • {0}',
  'شكل قايمة البلاغات':
      'Report list style',
  'مضغوطة':
      'Compact',
  'بطاقات كبيرة':
      'Large cards',
  'حجم الخط':
      'Font size',
  'صغير':
      'Small',
  'عادي':
      'Normal',
  'كبير':
      'Large',
  'كبير جداً':
      'Extra large',
  'بياناتي':
      'My details',
  'اسمي (بيتكتب تلقائي في البلاغات)':
      'My name (filled in reports automatically)',
  'السيرفر والمزامنة':
      'Server & sync',
  'تفعيل المزامنة مع السيرفر':
      'Enable sync with server',
  'البلاغات بتتبعت للسيرفر وتشوف بلاغات باقي المستخدمين':
      'Reports are sent to the server and you see other users\' reports',
  'رابط السيرفر (Project URL)':
      'Server URL (Project URL)',
  'المفتاح (anon / publishable key)':
      'Key (anon / publishable key)',
  'اختبار الاتصال':
      'Test connection',
  'مزامنة الآن':
      'Sync now',
  'نسخ سكربت إعداد قاعدة البيانات':
      'Copy database setup script',
  'ملاحظة: البلاغ اللي اتبعت للسيرفر مبيتمسحش (سجل رسمي)، بس بيتقفل من "تحديث الحالة". رقم البلاغ بيتحدد من السيرفر.':
      'Note: a report sent to the server is not deleted (official record), but it can be closed from "Update status". The report number is assigned by the server.',
  'عن التطبيق':
      'About',
  'الإصدار 2.0.0':
      'Version 2.0.0',
  'التفاصيل':
      'Details',
  'مفيش بلاغات عليها موقع لسه.\nلما تسجّل بلاغ والـ GPS شغال هيظهر هنا على الخريطة.':
      'No reports with a location yet.\nWhen you file a report with GPS on, it will appear here on the map.',
  'خريطة البلاغات ({0})  🔴 مفتوح  🟠 جاري  🟢 مغلق':
      'Reports map ({0})  🔴 Open  🟠 In progress  🟢 Closed',
  'شغّل الـ GPS من إعدادات الموبايل':
      'Turn on GPS in your phone settings',
  'مفيش صلاحية للوصول للموقع':
      'No permission to access location',
  'مقدرناش نحدد الموقع، جرّب تاني':
      'Could not get your location, try again',
  'لازم تضيف صورة للمخالفة':
      'You must add a photo of the violation',
  'اختار المكان':
      'Choose the location',
  'اختار نوع المخالفة':
      'Choose the violation type',
  'تم تسجيل البلاغ ✅':
      'Report saved ✅',
  'تم تسجيل البلاغ رقم {0} ✅':
      'Report No. {0} saved ✅',
  'حصل خطأ أثناء الحفظ، جرّب تاني':
      'An error occurred while saving, try again',
  'بلاغ جديد':
      'New report',
  'اضغط لإضافة صورة المخالفة *':
      'Tap to add a photo of the violation *',
  'تاريخ الرصد':
      'Date observed',
  'المكان *':
      'Location *',
  'نوع المخالفة *':
      'Violation type *',
  'الوصف':
      'Description',
  'مثال: وجود فلاتر أكياس خارج مخزن المخلفات الخطرة':
      'Example: used bag filters outside the hazardous waste store',
  'الجهة المسؤولة':
      'Responsible department',
  'بدون تحديد':
      'Not specified',
  'درجة الخطورة':
      'Severity',
  'بنحدد موقعك...':
      'Getting your location...',
  'تم تحديد الموقع (GPS)':
      'Location captured (GPS)',
  'الموقع غير محدد':
      'Location not set',
  'تفاصيل إضافية (اختياري)':
      'Additional details (optional)',
  'التأثير البيئي':
      'Environmental impact',
  'اسم المبلّغ':
      'Reporter name',
  'الإجراء التصحيحي المقترح':
      'Suggested corrective action',
  'تاريخ الاستحقاق للمعالجة':
      'Due date for correction',
  'تسجيل البلاغ':
      'Submit report',
  'حذف البلاغ؟':
      'Delete report?',
  'البلاغ هيتمسح نهائي من الموبايل.':
      'The report will be permanently deleted from this phone.',
  'حذف':
      'Delete',
  'بلاغ {0}':
      'Report {0}',
  'خطورة {0}':
      '{0} severity',
  'المبلّغ':
      'Reporter',
  'الإجراء التصحيحي':
      'Corrective action',
  'تاريخ الاستحقاق':
      'Due date',
  'تاريخ الإغلاق':
      'Closed date',
  'الإحداثيات':
      'Coordinates',
  'غير مسجّلة':
      'Not recorded',
  'تحديث الحالة / الإغلاق':
      'Update status / Close',
  'مشاركة (واتساب / إيميل)':
      'Share (WhatsApp / email)',
  'بلاغ مخالفة بيئية':
      'Environmental violation report',
  'ملف PDF':
      'PDF file',
  'فتح في الخرائط':
      'Open in maps',
  'تحديث حالة البلاغ':
      'Update report status',
  'الإجراء التصحيحي اللي اتعمل':
      'Corrective action taken',
  'تغيير صورة بعد المعالجة':
      'Change after-correction photo',
  'إضافة صورة بعد المعالجة':
      'Add after-correction photo',
  'حفظ':
      'Save',
  'مفيش بلاغات للتصدير':
      'No reports to export',
  'جاري تجهيز ملف PDF...':
      'Preparing PDF file...',
  'تعذّر إنشاء الملف، جرّب تاني':
      'Could not create the file, try again',
  'تعذّر إنشاء الـ PDF. تأكد من الإنترنت وجرّب تاني':
      'Could not create the PDF. Check your internet and try again',
  'وصل {0} بلاغ جديد 🔔':
      '{0} new reports received 🔔',
  'مفيش بلاغات جديدة':
      'No new reports',
  'بلاغات جديدة ({0})':
      'New reports ({0})',
  'تعليم الكل كمقروء':
      'Mark all as read',
  'الداشبورد':
      'Dashboard',
  'المصانع':
      'Factories',
  'المستخدمون':
      'Users',
  'لوحة المدير العام':
      'General manager dashboard',
  'البلاغات الجديدة':
      'New reports',
  'مزامنة':
      'Sync',
  'لسه مفيش مصانع. ضيفها من تبويب "المصانع".':
      'No factories yet. Add them from the "Factories" tab.',
  'أحدث البلاغات':
      'Latest reports',
  '{0} بلاغ':
      '{0} reports',
  '{0} متأخر':
      '{0} overdue',
  'نسبة الإغلاق {0}%':
      'Closure rate {0}%',
  'سجل المخالفات البيئية - {0}':
      'Environmental violations register - {0}',
  'مفيش بلاغات هنا.':
      'No reports here.',
  'حذف المصنع':
      'Delete factory',
  'هتحذف "{0}". لو عليه بلاغات مش هيتحذف.':
      'You are about to delete "{0}". It will not be deleted if it has reports.',
  'فشل الحذف':
      'Delete failed',
  'إضافة مصنع':
      'Add factory',
  'لسه مفيش مصانع.\nاضغط "إضافة مصنع" واكتب الاسم وارفع الشعار.':
      'No factories yet.\nTap "Add factory", enter the name and upload the logo.',
  'تعديل':
      'Edit',
  'اكتب اسم المصنع':
      'Enter the factory name',
  'مقدرناش نوصل للسيرفر':
      'Could not reach the server',
  'تعديل المصنع':
      'Edit factory',
  'الشعار':
      'Logo',
  'اسم المصنع':
      'Factory name',
  'تعذّر تحميل المستخدمين':
      'Could not load users',
  'ضيف مصنع الأول من تبويب المصانع':
      'Add a factory first from the Factories tab',
  'تم إنشاء الحساب ✅':
      'Account created ✅',
  'باسورد جديد لـ {0}':
      'New password for {0}',
  'تم تغيير الباسورد ✅':
      'Password changed ✅',
  'حذف الحساب':
      'Delete account',
  'هتحذف حساب "{0}". بلاغاته القديمة هتفضل.':
      'You are about to delete the account "{0}". Their old reports will remain.',
  'تحديث':
      'Refresh',
  'إضافة مبلّغ':
      'Add reporter',
  'تغيير الباسورد':
      'Change password',
  'اختار المصنع':
      'Choose the factory',
  'اسم المستخدم (إنجليزي)':
      'Username (English)',
  'الباسورد (٦ حروف على الأقل)':
      'Password (at least 6 characters)',
  'المصنع':
      'Factory',
  'إنشاء':
      'Create',
  'فشل الدخول (كود {0})':
      'Sign-in failed (code {0})',
  'تعذّر تحميل بيانات الحساب (كود {0})':
      'Could not load account data (code {0})',
  'تعذّر تحميل المصانع (كود {0})':
      'Could not load factories (code {0})',
  'دالة manage-users مش منشورة في Supabase لسه':
      'The manage-users function is not deployed in Supabase yet',
  'فشل الطلب (كود {0})':
      'Request failed (code {0})',
  'فشل رفع الشعار (كود {0}). تأكد إنك شغّلت سكربت v2':
      'Logo upload failed (code {0}). Make sure you ran script v2',
  'فشل حفظ المصنع (كود {0})':
      'Saving the factory failed (code {0})',
  'مينفعش تحذف مصنع عليه بلاغات':
      'You cannot delete a factory that has reports',
  'فشل الحذف (كود {0})':
      'Delete failed (code {0})',
  'فيه {0} بلاغ لسه ماتبعتش للسيرفر وهيتمسح لو خرجت. متأكد؟':
      '{0} report(s) have not been sent to the server yet and will be deleted if you sign out. Are you sure?',
  'هتخرج من حسابك. متأكد؟':
      'You will be signed out of your account. Are you sure?',
  'خروج':
      'Sign out',
  'مفتوح':
      'Open',
  'مغلق':
      'Closed',
  'تعذّرت المشاركة، جرّب تاني':
      'Sharing failed, try again',
  'مقدرناش نفتح الخرائط':
      'Could not open maps',
  'سجل المخالفات البيئية':
      'Environmental violations register',
  'بعد المعالجة':
      'After correction',
  'بلاغ في {0} مصنع':
      'reports across {0} factories',
  'نسبة الإغلاق':
      'Closure rate',
  '{0} مفتوح':
      '{0} open',
  '{0} جاري':
      '{0} in progress',
  '{0} مغلق':
      '{0} closed',
  'لسه مفيش بلاغات':
      'No reports yet',
};
