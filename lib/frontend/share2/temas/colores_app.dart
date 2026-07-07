import 'package:flutter/material.dart';

class ColoresApp {
  // ── Verdes — marca y acciones principales ────────────────────────────
  static const Color goGreen        = Color(0xFF01B763); // acción: botones primarios, precios, stock ok
  static const Color castletonGreen = Color(0xFF005B31); // hover de botones/elementos primarios
  static const Color brightGreen    = Color(0xFF2BD17E); // texto/ícono activo sobre el sidebar oscuro
  static const Color greenChipBg    = Color(0xFFE4F7EE); // fondo de chips de estado positivo (nunca fondo grande)

  // ── Oscuros — estructura, no acción ──────────────────────────────────
  static const Color blackChocolate = Color(0xFF16201B); // sidebar y botones secundarios "fuertes"
  static const Color textPrimary    = Color(0xFF19211D); // texto principal sobre fondo claro

  // ── Grises verdosos — SOLO dentro del sidebar oscuro ─────────────────
  static const Color textSidebar          = Color(0xFF93A29A); // ítem de nav inactivo (el más legible de los tres)
  static const Color textSidebarSecondary = Color(0xFF6E7F75); // subtítulo del sidebar ("Taller de motos")
  static const Color textSidebarLabel     = Color(0xFF566256); // etiquetas de sección (PRINCIPAL, TALLER…), el más apagado

  // ── Grises neutros — fondo y jerarquía en contenido claro ────────────
  static const Color bgApp       = Color(0xFFF4F5F6); // fondo general de la app
  static const Color bgCard      = Color(0xFFFFFFFF); // tarjetas, paneles, topbar
  static const Color bgCardHover = Color(0xFFFAFBFA); // hover sutil sobre tarjeta/fila
  static const Color bgInput     = Color(0xFFFAFBFA); // fondo de inputs y encabezado de tabla
  static const Color bgSidebar   = Color(0xFF16201B);

  static const Color border         = Color(0xFFEAECEA); // borde por defecto de cards, inputs y filas
  static const Color borderFocus    = Color(0xFF01B763); // borde de input enfocado
  static const Color borderSidebar  = Color(0xFF243128); // separador dentro del sidebar

  static const Color textSecondary = Color(0xFF5B6B61); // labels, subtítulos — el más legible de los tres grises
  static const Color textMuted     = Color(0xFF8A988F); // metadatos (fechas, SKU) — un escalón más suave
  static const Color textDisabled  = Color(0xFF9AA8A0); // placeholders, deshabilitado — el más tenue
  static const Color textOnPrimary = Color(0xFFFFFFFF); // texto sobre botón/fondo verde
  static const Color textLink      = Color(0xFF01B763);

  // ── Estados / badges (semáforo — uso puntual, no decorativo) ────────
  static const Color statusSuccess     = Color(0xFF01B763);
  static const Color statusSuccessBg   = Color(0xFFE4F7EE);
  static const Color statusWarning     = Color(0xFFE0892A);
  static const Color statusWarningBg   = Color(0xFFFFF4E5);
  static const Color statusDanger      = Color(0xFFE74C3C);
  static const Color statusDangerBg    = Color(0xFFFDECEA);
  static const Color statusInfo        = Color(0xFF3B82F6);
  static const Color statusInfoBg      = Color(0xFFEEF1FB);
  static const Color statusNeutral     = Color(0xFF5B6B61);
  static const Color statusNeutralBg   = Color(0xFFF0F2F0);

  static const Color stockOk       = Color(0xFF01B763);
  static const Color stockLow      = Color(0xFFE0892A);
  static const Color stockOut      = Color(0xFFE74C3C);

  static const Color shadow        = Color(0x0A000000);
  static const Color shadowMedium  = Color(0x1A000000);
}
