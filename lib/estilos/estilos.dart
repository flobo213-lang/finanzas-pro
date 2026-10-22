import 'package:flutter/material.dart';

// ============================================================
// PALETA DE COLORES - EXECUTIVE BLUE & MATTE FINISH
// ============================================================

class AppColors {
  // Azules Base y Menú Lateral
  static const Color azulOscuro =
      Color(0xFF0F172A); // Slate Navy (Súper sobrio)
  static const Color azulPrincipal = Color(0xFF1E293B); // Dark Slate
  static const Color azulClaro = Color(0xFF334155); // Muted Steel

  // Colores de Acento (Suaves, sin saturación chillona)
  static const Color verde = Color(0xFF0D9488); // Teal Muted (Elegante)
  static const Color rojo = Color(0xFF991B1B); // Deep Crimson
  static const Color naranja = Color(0xFFC2410C); // Burnt Orange

  // Fondos y Superficies
  static const Color fondo =
      Color(0xFFF1F5F9); // Cool Off-White (Descansa la vista)
  static const Color fondoAppBar = Color(0xFF0F172A);
  static const Color blanco = Color(0xFFFFFFFF);

  // Texto
  static const Color textoPrincipal = Color(0xFF0F172A);
  static const Color textoBlanco = Color(0xFFFFFFFF);
  static const Color textoSecundario = Color(0xFF64748B);

  // DEGRADADOS SERIOS PARA TARJETAS / TARJETAS DE BANCO
  static const LinearGradient degradadoAzulOscuro = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient degradadoAzulAcero = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF334155)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient degradadoGrisPremium = LinearGradient(
    colors: [Color(0xFF334155), Color(0xFF475569)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ============================================================
// ESTILOS DE DIÁLOGO
// ============================================================

class EstilosDialogo {
  static const forma = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );

  static const decoracion = BoxDecoration(
    color: AppColors.blanco,
    borderRadius: BorderRadius.all(Radius.circular(10)),
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  );

  static const padding = EdgeInsets.all(20);
  static const double ancho = 480;
}

// ============================================================
// ESTILOS DE TEXTO
// ============================================================

class EstilosTexto {
  static const titulo = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textoPrincipal,
  );

  static const subtitulo = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textoSecundario,
  );

  static const normal = TextStyle(
    fontSize: 13,
    color: AppColors.textoPrincipal,
  );

  static const normalBold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: AppColors.textoPrincipal,
  );

  static const pequeno = TextStyle(
    fontSize: 11,
    color: AppColors.textoSecundario,
  );

  static const boton = TextStyle(
    fontSize: 13,
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
  );

  static const botonVerde = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(AppColors.verde),
    foregroundColor: WidgetStatePropertyAll(Colors.white),
  );

  static const botonRojo = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(AppColors.rojo),
    foregroundColor: WidgetStatePropertyAll(Colors.white),
  );

  static const botonAzul = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(AppColors.azulPrincipal),
    foregroundColor: WidgetStatePropertyAll(Colors.white),
  );
}

// ============================================================
// DECORACIONES DE TARJETAS Y CONTENEDORES
// ============================================================

class EstilosDecoracion {
  static BoxDecoration tarjetaBlanca() {
    return BoxDecoration(
      color: AppColors.blanco,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class EstilosTarjeta {
  static BoxDecoration card({Color? color, Gradient? gradient}) {
    return BoxDecoration(
      color: color ?? AppColors.blanco,
      gradient: gradient,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
