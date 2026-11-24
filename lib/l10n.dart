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

const Map<String, String> _kEn = {
  // الشاشة الافتتاحية واختيار المصنع
  'رصد المخلفات': 'Waste Monitoring',
  'رصد المخلفات البيئية': 'Environmental Waste Monitoring',
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
};
