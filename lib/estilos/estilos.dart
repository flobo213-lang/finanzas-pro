import 'package:flutter/material.dart';

// ============================================================
// PALETA DE COLORES - EXECUTIVE BLUE & MATTE FINISH
// ============================================================
class AppColors {
  static const Color azulOscuro = Color(0xFF0F172A);
  static const Color azulPrincipal = Color(0xFF1E293B);
  static const Color azulClaro = Color(0xFF334155);
  static const Color verde = Color(0xFF0D9488);
  static const Color rojo = Color(0xFF991B1B);
  static const Color naranja = Color(0xFFC2410C);
  static const Color fondo = Color(0xFFF1F5F9);
  static const Color fondoAppBar = Color(0xFF0F172A);
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color textoPrincipal = Color(0xFF0F172A);
  static const Color textoBlanco = Color(0xFFFFFFFF);
  static const Color textoSecundario = Color(0xFF64748B);
}

// ============================================================
// ESTILOS DE DIÁLOGO Y RESPONSIVE (SE ADAPTA A CELULAR Y PC)
// ============================================================
class EstilosDialogo {
  static const forma = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  static double getAncho(BuildContext context, {double maxDesktop = 700}) {
    final size = MediaQuery.of(context).size;
    return size.width < 800 ? size.width * 0.95 : maxDesktop;
  }

  static double getAlto(BuildContext context, {double maxDesktop = 800}) {
    final size = MediaQuery.of(context).size;
    double altoCalculado = size.height * 0.90;
    return altoCalculado > maxDesktop ? maxDesktop : altoCalculado;
  }

  static EdgeInsets getPadding(BuildContext context) {
    return MediaQuery.of(context).size.width < 700
        ? const EdgeInsets.all(16)
        : const EdgeInsets.all(24);
  }
}

// ============================================================
// ESTILOS DE TEXTO (FUENTES MÁS GRANDES Y LEGIBLES)
// ============================================================
class EstilosTexto {
  static const titulo = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textoPrincipal,
  );

  static const subtitulo = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textoPrincipal,
  );

  static const normal = TextStyle(
    fontSize: 15,
    color: AppColors.textoPrincipal,
  );

  static const normalBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: AppColors.textoPrincipal,
  );

  static const pequeno = TextStyle(
    fontSize: 13,
    color: AppColors.textoSecundario,
  );

  static const boton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}

// ============================================================
// ESTILOS DE BOTONES
// ============================================================
class EstilosBotones {
  static const botonGris = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(Color(0xFF64748B)),
    foregroundColor: WidgetStatePropertyAll(Colors.white),
    minimumSize: WidgetStatePropertyAll(Size(120, 48)),
  );

  static const botonVerde = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(AppColors.verde),
    foregroundColor: WidgetStatePropertyAll(Colors.white),
    minimumSize: WidgetStatePropertyAll(Size(120, 48)),
  );

  static const botonRojo = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(AppColors.rojo),
    foregroundColor: WidgetStatePropertyAll(Colors.white),
    minimumSize: WidgetStatePropertyAll(Size(120, 48)),
  );

  static const botonAzul = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(AppColors.azulPrincipal),
    foregroundColor: WidgetStatePropertyAll(Colors.white),
    minimumSize: WidgetStatePropertyAll(Size(120, 48)),
  );
}

// ============================================================
// DECORACIONES
// ============================================================
class EstilosDecoracion {
  static BoxDecoration tarjetaBlanca() {
    return BoxDecoration(
      color: AppColors.blanco,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
