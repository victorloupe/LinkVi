# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users
Lojistas, criadores de conteúdo, pequenos negócios, restaurantes, profissionais autônomos e prestadores de serviços que precisam de um hub de links centralizado, elegante e de alta conversão para redes sociais (Instagram, TikTok, WhatsApp, etc.).

## Product Purpose
O LinkVi é uma plataforma SaaS multi-tenant que permite a criação, personalização em tempo real e análise de desempenho de páginas de links e cardápios digitais para bio, com rastreamento de cliques e métricas em tempo real.

## Positioning
Simplicidade extrema com nível de customização visual profissional, carregamento instantâneo via CDN/Supabase, visualizador em tempo real integrado ao painel e recursos avançados de conversão (WhatsApp com mensagem prévia, visualizador de PDF/catálogo integrado, carrossel de fotos, chaves PIX e integração de mapas).

## Operating Context
- **Painel Administrativo (`index.html`)**: Utilizado em desktop ou mobile para customizar temas/cores, cadastrar e reordenar links, ativar/desativar botões e acompanhar o painel analítico de métricas.
- **Página Pública do Cliente (`cliente.html`)**: Acessada majoritariamente por smartphones via links da bio, exigindo carregamento ultrarrápido, compatibilidade com entalhes de tela (notches, safe-areas) e fluidez máxima.

## Capabilities and Constraints
- **Backend Supabase**: PostgreSQL com RLS, Auth para autenticação de administradores/lojistas e Storage para logos, ícones e arquivos PDF.
- **Serverless Share Engine (`api/share.js`)**: Renderização dinâmica de meta tags Open Graph no Vercel para compartilhamentos ricos no WhatsApp, Facebook e Twitter.
- **Tipos de Links Suportados**: URL Padrão, Construtor de WhatsApp com mensagem pré-definida, Construtor de E-mail, Telefone Direto, Visualizador de Catálogo/PDF integrado, Carrossel de Imagens, Endereço no Mapa, Chave PIX e Agendamento.
- **Métricas em Tempo Real**: Rastreamento de visualizações de página, contagem de cliques por link, taxa de clique (CTR) e gráficos temporais por dia da semana e mês.

## Brand Commitments
- **Nome**: LinksVi (ou LinkVi).
- **Estilo**: Moderno, minimalista, limpo e premium. Deve transmitir profissionalismo, agilidade e credibilidade.

## Evidence on Hand
- Código fonte funcional em `index.html` (painel administrativo), `cliente.html` (página pública do cliente), `api/share.js` (gerador OG), `vercel.json` e `supabase_security_hardening.sql`.

## Product Principles
1. **Velocidade e Resposta Instantânea**: A página do cliente deve abrir em milissegundos sem travamentos ou reflows no mobile.
2. **Edição Intuitiva com Feedback Imediato**: Toda alteração no painel administrativo reflete instantaneamente no simulador de celular.
3. **Conversão Focada no Ação**: Botões claros, legíveis e com micro-interações táteis de alta qualidade.
4. **Resiliência e Robustez**: Se uma imagem ou asset falhar, a interface mantém a elegância com fallbacks sem quebras.
