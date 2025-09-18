// lib/Offisant/offisant.dart

// SDK
export 'dart:convert';
export 'dart:io';
export 'dart:async';
import 'package:intl/intl.dart';

// Packages
export 'package:flutter/material.dart';
export 'package:auto_size_text/auto_size_text.dart';

// Eslatma: export alias (masalan, `as http`) qo‘llab-quvvatlanmaydi.
// Agar `http` uchun prefiks kerak bo‘lsa, uni alohida `import as http` qiling.

// App ichidagi fayllar
export 'package:sora/Offisant/Page/Categorya.dart';
export 'package:sora/Offisant/Page/Yopilgan_zakaz_page.dart';
export 'package:sora/Admin/Page/Stollarni_joylashuv.dart';

export 'package:sora/Offisant/Controller/TokenCOntroller.dart';
export 'package:sora/Offisant/Controller/usersCOntroller.dart';
export 'package:sora/Offisant/Model/Ovqat_model.dart';
