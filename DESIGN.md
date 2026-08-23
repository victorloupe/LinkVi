---
name: LinkVi Design System
description: Sistema visual moderno, responsivo e de alta conversão para criação e gestão de páginas bio de links e cardápios digitais.
colors:
  primary: "#6366f1"
  primary-deep: "#4f46e5"
  brand-purple: "#372f6b"
  brand-purple-hover: "#453c85"
  neutral-bg: "#f8fafc"
  panel-white: "#ffffff"
  text-main: "#0f172a"
  text-muted: "#64748b"
  border-color: "#e2e8f0"
  success: "#10b981"
  danger: "#ef4444"
typography:
  display:
    fontFamily: "'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
    fontSize: "clamp(1.75rem, 4vw, 2.5rem)"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.025em"
  headline:
    fontFamily: "'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
    fontSize: "clamp(1.25rem, 2.5vw, 1.625rem)"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "-0.02em"
  title:
    fontFamily: "'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
    fontSize: "1rem"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "-0.01em"
  body:
    fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "normal"
  label:
    fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "0.02em"
rounded:
  sm: "6px"
  md: "10px"
  lg: "16px"
  full: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.brand-purple}"
    textColor: "{colors.panel-white}"
    rounded: "{rounded.md}"
    padding: "10px 18px"
  button-primary-hover:
    backgroundColor: "{colors.brand-purple-hover}"
---

# Design System: LinkVi

## Overview

**Creative North Star: "The Modern Conversion Hub"**

O LinkVi combina a precisão funcional de uma ferramenta de produtividade (modo *Operate* no painel administrativo) com a expressividade visual e impacto de conversão de uma vitrine digital (modo *Persuade* na página pública do cliente). 

A interface rejeita o visual genérico e saturado de painéis de IA padrão em favor de linhas limpas, contraste tipográfico preciso com Plus Jakarta Sans e Inter, sombras neutras de elevação com difusão suave e micro-interações táteis de alta fidelidade.

**Key Characteristics:**
- **Clareza Operacional:** Painel sem ruído visual, com hierarquia clara e simulador de celular responsivo.
- **Acabamento Premium:** Superfícies translúcidas em vidro fosco (*glassmorphism* refinado), bordas sutis e foco visual nos links de conversão.
- **Desempenho Sem Reflow:** Transições 100% aceleradas por hardware usando `transform` e `opacity`.

## Colors

A paleta equilibra um fundo neutro suave com tons profundos de azul/índigo para autoridade e acentos de destaque para conversão.

### Primary
- **Brand Purple** (`#372f6b`): Cor primária de identidade do painel, botões de ação e estados ativos.
- **Brand Indigo** (`#6366f1`): Acento vibrante para gradientes de destaque e badges.

### Neutral
- **Background Light** (`#f8fafc`): Fundo geral suave que evita fadiga ocular.
- **Panel White** (`#ffffff`): Fundo de cartões e superfícies modais.
- **Text Main** (`#0f172a`): Texto primário de alto contraste (WCAG AAA).
- **Text Muted** (`#64748b`): Rótulos secundários e instruções de auxílio.
- **Border Subtle** (`#e2e8f0`): Divisores e contornos finos de 1px.

### Semantic
- **Success** (`#10b981`): Status de salvamento automático e links ativos.
- **Danger** (`#ef4444`): Ações destrutivas e alertas de erro.

### Named Rules
**The Single Focus Rule.** O acento vibrante é aplicado apenas no elemento prioritário de conversão na tela. Elementos secundários utilizam contraste tonal neutro.

## Typography

**Display / Headline Font:** Plus Jakarta Sans (com fallback system-ui)  
**Body / Controls Font:** Inter (com fallback system-ui)  

**Character:** A combinação traz o peso geométrico e contemporâneo do Plus Jakarta Sans nos títulos com a legibilidade impecável do Inter no corpo de texto e controles.

### Hierarchy
- **Display** (700, `clamp(1.75rem, 4vw, 2.5rem)`, 1.2): Títulos de perfil na página do cliente e heróis.
- **Headline** (600, `clamp(1.25rem, 2.5vw, 1.625rem)`, 1.3): Títulos de seções no painel e chamadas de ação.
- **Title** (600, `1rem`, 1.4): Nomes de links e cabeçalhos de cards.
- **Body** (400, `0.875rem`, 1.5): Textos de formulários, descrições e inputs.
- **Label** (600, `0.75rem`, 1.4): Badges de status, abas e tags de estatísticas.

### Named Rules
**The Tabular Metric Rule.** Números em dashboards analíticos utilizam `font-feature-settings: 'tnum'` e `letter-spacing: -0.02em` para alinhamento vertical perfeito.

## Layout

O painel utiliza um layout em grid de 2 colunas no desktop: área de configuração/edição (à esquerda) e simulador do smartphone em posição sticky (à direita). No mobile, o layout se reorganiza em abas fluidas com acesso rápido ao preview.

- **Espaçamento Base:** Escala modular em múltiplos de 4px / 8px (4, 8, 12, 16, 24, 32, 48px).
- **Safe Area Insets:** A página do cliente respeita `env(safe-area-inset-top)` e `env(safe-area-inset-bottom)` para perfeita adaptação em iPhones com Dynamic Island e Androids modernos.

## Elevation & Depth

Utiliza sombras multicamadas em tons neutros de slate/preto (`rgba(15, 23, 42, ...)`), eliminando o glow monocromático artificial.

### Shadow Vocabulary
- **Elevation Low** (`0 1px 3px 0 rgba(15, 23, 42, 0.06), 0 1px 2px -1px rgba(15, 23, 42, 0.04)`): Cards estáticos, inputs e botões secundários.
- **Elevation Medium** (`0 4px 6px -1px rgba(15, 23, 42, 0.08), 0 2px 4px -2px rgba(15, 23, 42, 0.04)`): Cards interativos de links e menus dropdown.
- **Elevation High** (`0 20px 25px -5px rgba(15, 23, 42, 0.1), 0 8px 10px -6px rgba(15, 23, 42, 0.04)`): Modais, toasts e gavetas retráteis.

## Shapes

- **Contornos:** Bordas finas de 1px com `rgba(226, 232, 240, 0.8)`.
- **Raios de Curvatura:** 
  - `6px` para badges e pequenos controles.
  - `10px` para inputs e botões padrão.
  - `16px` para painéis e cartões.
  - `9999px` (Pill) para botões de links na página do cliente quando configurado.

## Components

### Buttons
- **Shape:** Raio de 10px (`--radius-md`).
- **Primary:** Fundo `#372f6b`, texto branco, padding `10px 18px`, transição suave de escala (`scale(0.98)` no clique).
- **Hover:** Transição para `#453c85` com elevação sutil.
- **Ghost / Outline:** Fundo transparente com borda de 1px sutil e texto em slate-700.

### Link Buttons (Página Pública)
- **Shape:** Raio customizável (Pill, Médio ou Quadrado) com suporte a temas Sólido, Outline, Glassmorphism e Sombra Flutuante.
- **Micro-interação:** Elevação de 2px no hover (`translateY(-2px)`) com curva exponencial (`cubic-bezier(0.16, 1, 0.3, 1)`).

### Inputs
- **Style:** Fundo branco, borda `1px solid #e2e8f0`, padding `10px 14px`, raio de 8px.
- **Focus:** Borda ativa com anel suave de foco sem deslocamento de layout.

## Do's and Don'ts

### Do:
- **Do** usar curvas de aceleração exponencial (`cubic-bezier(0.16, 1, 0.3, 1)`) para transições suaves.
- **Do** manter a hierarquia de fontes com Plus Jakarta Sans nos títulos e Inter no corpo.
- **Do** garantir que qualquer elemento interativo tenha estado de hover, foco visível e feedback de clique.
- **Do** tratar safe areas em dispositivos móveis.

### Don't:
- **Don't** animar `width`, `height`, `margin` ou `padding` diretamente (use `transform` e `opacity`).
- **Don't** utilizar glow neon roxo sem offset (`box-shadow: 0 0 15px #7c3aed`).
- **Don't** deixar tags `<img>` com `src=""` que renderizam caixas de imagem quebradas.
- **Don't** utilizar curvas de easing elásticas ou com bounce (`cubic-bezier(0.34, 1.56, ...)`).
