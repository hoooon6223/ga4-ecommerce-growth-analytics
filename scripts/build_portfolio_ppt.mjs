import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
const workspaceDir = process.cwd();
const skillDir = process.env.PRESENTATIONS_SKILL_DIR
  ?? "/Users/hyeon/.codex/plugins/cache/openai-primary-runtime/presentations/26.904.11930/skills/presentations";
const tmpDir = path.join(workspaceDir, ".codex-build", "portfolio-ppt");
const finalPath = path.join(workspaceDir, "outputs", "pptx", "ga4_product_analytics_portfolio_v6.pptx");
const runtimePython = process.env.RUNTIME_PYTHON
  ?? "/Users/hyeon/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3";
const runtimeNodeModules = process.env.RUNTIME_NODE_MODULES
  ?? "/Users/hyeon/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules";
process.env.RUNTIME_NODE_MODULES = runtimeNodeModules;

const { Presentation, PresentationFile } = await import(
  pathToFileURL(path.join(runtimeNodeModules, "@oai", "artifact-tool", "dist", "artifact_tool.mjs")).href
);

const { resolvePresentationFont, applyPresentationChartFont, finalizePresentation } = await import(
  pathToFileURL(path.join(skillDir, "container_tools", "artifact_tool_utils.mjs")).href
);

await fs.mkdir(tmpDir, { recursive: true });
await fs.mkdir(path.dirname(finalPath), { recursive: true });

const font = resolvePresentationFont({ fontFamily: "Apple SD Gothic Neo" });
const deck = Presentation.create({ slideSize: { width: 1280, height: 720 } });

const C = {
  ink: "#102033",
  muted: "#5A6678",
  line: "#D8DEE8",
  bg: "#F7F8FB",
  white: "#FFFFFF",
  blue: "#2D6CDF",
  teal: "#0F9F8F",
  amber: "#E5A100",
  coral: "#E76F51",
  slate: "#E9EEF5",
  green: "#1B8A5A",
};

function addSlide(title, kicker = "") {
  const slide = deck.slides.add();
  slide.background.fill = C.bg;
  const titleBox = slide.shapes.add({
    geometry: "textbox",
    position: { left: 56, top: 34, width: 930, height: 52 },
    fill: "none",
    line: { fill: "none", width: 0 },
  });
  titleBox.text = title;
  titleBox.text.style = { typeface: font, fontSize: 31, bold: true, color: C.ink, autoFit: "shrinkText" };
  if (kicker) {
    const k = slide.shapes.add({
      geometry: "textbox",
      position: { left: 1010, top: 44, width: 210, height: 30 },
      fill: "none",
      line: { fill: "none", width: 0 },
    });
    k.text = kicker;
    k.text.style = { typeface: font, fontSize: 12, color: C.muted, alignment: "right" };
  }
  const rule = slide.shapes.add({
    geometry: "rect",
    position: { left: 56, top: 92, width: 1168, height: 1.5 },
    fill: C.line,
    line: { fill: "none", width: 0 },
  });
  return slide;
}

function textbox(slide, text, left, top, width, height, opts = {}) {
  const box = slide.shapes.add({
    geometry: "textbox",
    position: { left, top, width, height },
    fill: opts.fill ?? "none",
    line: opts.line ?? { fill: "none", width: 0 },
  });
  box.text = text;
  box.text.style = {
    typeface: font,
    fontSize: opts.fontSize ?? 18,
    bold: opts.bold ?? false,
    color: opts.color ?? C.ink,
    alignment: opts.alignment ?? "left",
    autoFit: opts.autoFit ?? "shrinkText",
  };
  return box;
}

function stat(slide, label, value, left, top, width, color = C.blue) {
  const g = slide.shapes.add({
    geometry: "rect",
    position: { left, top, width, height: 86 },
    fill: C.white,
    line: { fill: C.line, width: 1 },
  });
  textbox(slide, value, left + 18, top + 14, width - 36, 34, { fontSize: 26, bold: true, color });
  textbox(slide, label, left + 18, top + 52, width - 36, 24, { fontSize: 13, color: C.muted });
  return g;
}

function note(slide, text, left, top, width, height) {
  const box = slide.shapes.add({
    geometry: "rect",
    position: { left, top, width, height },
    fill: "#FFF8E6",
    line: { fill: "#F0C96B", width: 1 },
  });
  textbox(slide, text, left + 16, top + 12, width - 32, height - 18, { fontSize: 15, color: C.ink });
  return box;
}

function smallLabel(slide, text, left, top, width, color = C.muted) {
  return textbox(slide, text, left, top, width, 22, { fontSize: 12, color });
}

function addTable(slide, values, left, top, width, height, colWidths = null) {
  const table = slide.tables.add({
    rows: values.length,
    columns: values[0].length,
    left,
    top,
    width,
    height,
    values,
    ...(colWidths ? { columnWidths: colWidths } : {}),
  });
  table.styleOptions = { headerRow: true, bandedRows: true };
  table.borders.assign({ style: "solid", fill: C.line, width: 1 });
  table.cells.block({ row: 0, column: 0, rowCount: 1, columnCount: values[0].length }).assign({
    fill: C.ink,
    textStyle: { typeface: font, color: C.white, bold: true, fontSize: 12 },
  });
  table.cells.block({ row: 1, column: 0, rowCount: values.length - 1, columnCount: values[0].length }).assign({
    textStyle: { typeface: font, color: C.ink, fontSize: 13 },
    margins: { left: 7, right: 7, top: 5, bottom: 5 },
  });
  return table;
}

function applyChartFont(chart) {
  applyPresentationChartFont(chart, { fontFamily: font });
  return chart;
}

function addArrow(slide, x1, y1, x2, y2, color = C.line) {
  slide.shapes.add({
    geometry: "line",
    position: { left: x1, top: y1, width: x2 - x1, height: y2 - y1 },
    fill: "none",
    line: { style: "solid", fill: color, width: 2, endArrowType: "triangle" },
  });
}

function card(slide, title, body, left, top, width, height, color = C.blue) {
  slide.shapes.add({
    geometry: "rect",
    position: { left, top, width, height },
    fill: C.white,
    line: { fill: C.line, width: 1 },
  });
  slide.shapes.add({
    geometry: "rect",
    position: { left, top, width: 6, height },
    fill: color,
    line: { fill: "none", width: 0 },
  });
  textbox(slide, title, left + 20, top + 14, width - 34, 28, { fontSize: 17, bold: true, color: C.ink });
  textbox(slide, body, left + 20, top + 48, width - 34, height - 54, { fontSize: 14, color: C.muted });
}

function addNotes(slide, text) {
  slide.speakerNotes.textFrame.setText(text);
}

// Cover
{
  const s = deck.slides.add();
  s.background.fill = C.bg;
  textbox(s, "Product Data Analytics Portfolio", 72, 72, 760, 36, { fontSize: 18, bold: true, color: C.blue });
  textbox(s, "GA4 이커머스 매출 성장 분석", 72, 150, 860, 70, { fontSize: 42, bold: true, color: C.ink });
  textbox(s, "데이터 마트 구축부터 행동 진단, 제품 가설, A/B 테스트 시뮬레이션까지", 72, 230, 880, 42, {
    fontSize: 22,
    color: C.muted,
  });
  stat(s, "Business goal", "Weekly revenue growth", 72, 340, 310, C.green);
  stat(s, "Main lever", "Buyer CVR", 410, 340, 250, C.coral);
  stat(s, "Target scope", "NAU Home Landing", 688, 340, 300, C.teal);
  card(s, "Portfolio scope", "BigQuery GA4 public dataset 기반으로 event/session/order/item mart를 만들고, first-session discovery 병목을 제품 실험 질문으로 연결했다.", 72, 480, 540, 118, C.blue);
  card(s, "Author", "현승훈\nData Analyst Portfolio", 650, 480, 338, 118, C.ink);
  textbox(s, "Dataset: bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*", 72, 638, 870, 24, { fontSize: 13, color: C.muted });
  addNotes(s, "Cover slide for the portfolio deck.");
}

// Slide 1
{
  const s = addSlide("프로젝트 개요: 주별 매출 성장을 위한 행동 분석", "GA4 Ecommerce");
  textbox(s, "GA4 raw event를 분석 가능한 mart로 만들고, 매출 성장 질문을 제품 실험까지 연결했다.", 72, 120, 760, 74, {
    fontSize: 26,
    bold: true,
  });
  stat(s, "Dataset", "GA4 sample ecommerce", 72, 226, 270, C.blue);
  stat(s, "Main period", "2020.11.23-12.20", 370, 226, 270, C.teal);
  stat(s, "Business goal", "Weekly revenue", 668, 226, 270, C.coral);
  card(s, "Why weekly", "Daily는 요일과 트래픽 노이즈가 크고, monthly는 샘플 기간상 관측치가 적다. Weekly는 WAU, Buyer CVR, ARPPU를 안정적으로 비교하면서 실험 기간 산정과 연결하기 좋다.", 72, 346, 520, 136, C.amber);
  card(s, "Project flow", "Data mart 구성, revenue decomposition, cohort 선택, first-session funnel, WHY 진단, synthetic A/B test, modeled revenue opportunity까지 연결한다.", 620, 346, 520, 136, C.teal);
  textbox(s, "Output: 데이터 마트, 분석 SQL, metric definition, A/B simulation, 포트폴리오 슬라이드", 72, 620, 1000, 28, { fontSize: 15, color: C.muted });
  addNotes(s, "The slide introduces the project scope and explains why the analysis uses weekly revenue rather than daily or monthly metrics.");
}

// Slide 2
{
  const s = addSlide("분석 기반 구축: GA4 데이터 마트 설계", "Data Mart");
  textbox(s, "Raw event log를 event, session, order, item grain으로 분리해 퍼널과 매출 분석 기준을 만들었다.", 72, 112, 760, 48, { fontSize: 22, bold: true });
  const xs = [90, 370, 650, 930];
  card(s, "Raw GA4 Events", "event_name, event_params, user_pseudo_id, items", xs[0], 210, 210, 96, C.ink);
  card(s, "Base marts", "base_f_event_wide\nbase_f_order_items", xs[1], 210, 210, 96, C.blue);
  card(s, "Core marts", "core_f_sessions\ncore_f_orders\ncore_d_items", xs[2], 210, 210, 96, C.teal);
  card(s, "Analysis layer", "revenue, cohort, funnel, WHY, A/B SQL", xs[3], 210, 210, 96, C.coral);
  addArrow(s, 302, 258, 364, 258, C.muted);
  addArrow(s, 582, 258, 644, 258, C.muted);
  addArrow(s, 862, 258, 924, 258, C.muted);
  addTable(s, [
    ["Table", "Grain", "Purpose"],
    ["base_f_event_wide", "1 event", "event_seq 기반 행동 로그"],
    ["base_f_order_items", "purchase x item", "item revenue와 category 분석"],
    ["core_f_sessions", "1 session", "세션 행동과 유입 요약"],
    ["core_f_orders", "1 purchase", "order-level revenue"],
    ["core_d_items", "1 item_id", "관측 상품 dimension"],
  ], 88, 380, 1080, 210, [260, 220, 600]);
  note(s, "purchase_revenue는 order grain, item_revenue는 item grain으로 사용한다.", 760, 116, 380, 64);
  addNotes(s, "This slide shows the modeling work before analysis. The main defense point is separating grains before calculating KPIs.");
}

// Slide 3
{
  const s = addSlide("비즈니스 목표 구조화: 주별 매출 분해", "Revenue");
  textbox(s, "Weekly Revenue = WAU x Weekly Buyer CVR x ARPPU", 86, 115, 780, 44, { fontSize: 27, bold: true, color: C.ink });
  stat(s, "Average Weekly Revenue", "$49.5K", 910, 110, 230, C.green);
  const categories = ["11/23", "11/30", "12/07", "12/14"];
  const rev = [100, 90, 125, 99];
  const wau = [100, 111, 142, 124];
  const cvr = [100, 104, 104, 85];
  const arppu = [100, 78, 84, 94];
  const chart = s.charts.add("line", {
    position: { left: 80, top: 205, width: 760, height: 350 },
    categories,
    series: [
      { name: "Revenue", values: rev, line: { style: "solid", fill: C.blue, width: 3 } },
      { name: "WAU", values: wau, line: { style: "solid", fill: C.teal, width: 3 } },
      { name: "Buyer CVR", values: cvr, line: { style: "solid", fill: C.coral, width: 3 } },
      { name: "ARPPU", values: arppu, line: { style: "solid", fill: C.amber, width: 3 } },
    ],
    hasLegend: true,
    legend: { position: "bottom", textStyle: { fontSize: 12, fill: C.muted } },
    yAxis: { numberFormatCode: "0", majorGridlines: { style: "solid", fill: C.line, width: 1 }, textStyle: { fontSize: 11, fill: C.muted } },
    xAxis: { textStyle: { fontSize: 11, fill: C.muted } },
  });
  applyChartFont(chart);
  card(s, "Scope decision", "WAU는 유입, ARPPU는 가격과 장바구니 전략에 가깝다. 이번 프로젝트는 GA4 행동로그로 직접 진단 가능한 Buyer CVR을 분석 scope로 잡았다.", 885, 230, 300, 170, C.coral);
  card(s, "Chart basis", "각 라인은 첫 주를 100으로 둔 index다. 서로 다른 단위의 지표를 같은 축에서 비교하기 위한 표현이다.", 885, 430, 300, 120, C.blue);
  addNotes(s, "Source data: outputs/data/weekly_revenue_decomposition_main_period.csv. Index values are rounded from the four ALL weekly rows.");
}

// Slide 4
{
  const s = addSlide("타겟 선정: 어떤 사용자를 우선 볼 것인가", "WHO");
  textbox(s, "Merchandise Store는 구매 목적의 이커머스이므로 신규/첫 방문 경험이 중요하며, 데이터에서도 NAU가 큰 pool로 관측되었다.", 72, 112, 980, 50, { fontSize: 21, bold: true });
  const chart = s.charts.add("bar", {
    position: { left: 90, top: 205, width: 630, height: 330 },
    categories: ["NAU", "EAU", "RAU"],
    series: [{ name: "Active User-Weeks Share", values: [0.904, 0.057, 0.039], fill: C.blue }],
    barOptions: { direction: "bar", grouping: "clustered", gapWidth: 48 },
    hasLegend: false,
    xAxis: { min: 0, max: 1, numberFormatCode: "0%", majorGridlines: { style: "solid", fill: C.line, width: 1 }, textStyle: { fontSize: 11, fill: C.muted } },
    yAxis: { textStyle: { fontSize: 13, fill: C.ink } },
  });
  applyChartFont(chart);
  addTable(s, [
    ["Segment", "Share", "Buyer CVR"],
    ["NAU", "90.4%", "1.63%"],
    ["EAU", "5.7%", "7.32%"],
    ["RAU", "3.9%", "8.09%"],
  ], 790, 218, 330, 170, [120, 100, 110]);
  note(s, "NAU가 항상 더 중요하다는 뜻이 아니다. 관측 데이터와 프로젝트 목적상 first-session 전환 진단에 적합한 scope다.", 790, 420, 330, 96);
  addNotes(s, "Active User-Weeks are not four-week unique users. They are weekly user observations across the main period.");
}

// Slide 5
{
  const s = addSlide("병목 진단: 신규 유저 첫 세션 퍼널", "WHERE");
  textbox(s, "같은 first session 안에서 event_seq 순서를 강제해 실제 순차 퍼널을 확인했다.", 72, 112, 900, 40, { fontSize: 22, bold: true });
  const chart = s.charts.add("bar", {
    position: { left: 76, top: 190, width: 815, height: 360 },
    categories: ["View Item", "Add to Cart", "Checkout", "Purchase"],
    series: [
      { name: "NAU", values: [0.2128, 0.0548, 0.0178, 0.0075], fill: C.blue },
      { name: "EAU", values: [0.3031, 0.0862, 0.0339, 0.0234], fill: C.teal },
      { name: "RAU", values: [0.4069, 0.1330, 0.0558, 0.0380], fill: C.coral },
    ],
    barOptions: { direction: "column", grouping: "clustered", gapWidth: 55 },
    hasLegend: true,
    legend: { position: "bottom", textStyle: { fontSize: 12, fill: C.muted } },
    yAxis: { min: 0, max: 0.45, numberFormatCode: "0%", majorGridlines: { style: "solid", fill: C.line, width: 1 }, textStyle: { fontSize: 11, fill: C.muted } },
    xAxis: { textStyle: { fontSize: 11, fill: C.ink } },
  });
  applyChartFont(chart);
  card(s, "Sequential rule", "same first session\nevent_seq 기준 순서 강제\n이전 단계 이후 다음 단계 발생 시 통과", 930, 200, 250, 136, C.ink);
  card(s, "Initial discovery gap", "View Item 도달률\nNAU 21.3%\nEAU 30.3%\nRAU 40.7%", 930, 366, 250, 130, C.coral);
  note(s, "NAU의 상대적 gap은 첫 상품 상세 진입에서 이미 크게 나타난다.", 92, 560, 640, 58);
  addNotes(s, "Source data: outputs/data/segment_week_first_session_funnel_main_period.csv.");
}

// Slide 6
{
  const s = addSlide("진입 맥락 분석: Home Landing의 기회 영역", "Entry Context");
  textbox(s, "Home Landing은 큰 entry context지만 View Item까지 이어지는 비율은 20.70%에 그쳤다.", 72, 112, 940, 42, { fontSize: 22, bold: true });
  const chart = s.charts.add("bar", {
    position: { left: 95, top: 190, width: 600, height: 350 },
    categories: ["Home Landing", "Reached Item List", "Reached View Item", "Reached Cart"],
    series: [{ name: "Sessions", values: [46923, 16909, 9711, 3516], fill: C.teal }],
    barOptions: { direction: "bar", grouping: "clustered", gapWidth: 42 },
    hasLegend: false,
    xAxis: { min: 0, max: 50000, numberFormatCode: "#,##0", majorGridlines: { style: "solid", fill: C.line, width: 1 }, textStyle: { fontSize: 11, fill: C.muted } },
    yAxis: { textStyle: { fontSize: 12, fill: C.ink } },
  });
  applyChartFont(chart);
  addTable(s, [
    ["Metric", "Sessions", "Rate"],
    ["Home Landing", "46,923", "100.00%"],
    ["Reached Item List", "16,909", "36.04%"],
    ["Used Search", "2,593", "5.53%"],
    ["Reached View Item", "9,711", "20.70%"],
    ["Cart after View Item", "3,516", "36.21%"],
  ], 760, 198, 390, 250, [180, 105, 105]);
  note(s, "Home에서 View Item까지의 discovery 구간을 다음 분석 대상으로 설정했다.", 760, 478, 390, 70);
  addNotes(s, "Home landing includes '/', '/store.html', and Home / Google Online Store page titles.");
}

// Slide 7
{
  const s = addSlide("진단 세그먼트 분리: Qualified Home", "Diagnostic");
  textbox(s, "No-exploration은 별도 engagement 문제로 분리하고, 최소 탐색 행동이 시작된 Qualified Home에서 WHY를 진단했다.", 72, 110, 980, 46, { fontSize: 21, bold: true });
  const donut = s.charts.add("doughnut", {
    position: { left: 75, top: 190, width: 380, height: 300 },
    categories: ["No-exploration", "Qualified Home"],
    series: [{ name: "Sessions", values: [11562, 35361], points: [{ idx: 0, fill: C.amber }, { idx: 1, fill: C.teal }] }],
    doughnutOptions: { holeSize: 58 },
    dataLabels: { showPercent: true, showCategoryName: true, position: "outEnd", textStyle: { fontSize: 12, fill: C.ink } },
    hasLegend: false,
  });
  applyChartFont(donut);
  const bar = s.charts.add("bar", {
    position: { left: 520, top: 206, width: 610, height: 290 },
    categories: ["home/other no view", "item_list to view", "item_list no view"],
    series: [{ name: "Share of Qualified Home", values: [0.5009, 0.2383, 0.1962], fill: C.blue }],
    barOptions: { direction: "bar", grouping: "clustered", gapWidth: 42 },
    hasLegend: false,
    xAxis: { min: 0, max: 0.55, numberFormatCode: "0%", majorGridlines: { style: "solid", fill: C.line, width: 1 }, textStyle: { fontSize: 11, fill: C.muted } },
    yAxis: { textStyle: { fontSize: 12, fill: C.ink } },
  });
  applyChartFont(bar);
  note(s, "WHY 질문: Home에 진입한 뒤 최소한의 탐색 행동을 시작한 사용자는 왜 View Item까지 이어지지 않는가?", 105, 525, 980, 62);
  addNotes(s, "Qualified Home is a diagnostic post-behavior segment, not the A/B test eligibility population.");
}

// Slide 8
{
  const s = addSlide("원인 진단: 왜 View Item까지 이어지지 않는가", "WHY");
  textbox(s, "여러 WHY 후보를 지표 패턴으로 확인한 뒤, discovery 선택 전환 부족을 주요 후보로 좁혔다.", 72, 112, 940, 42, { fontSize: 21, bold: true });
  addTable(s, [
    ["WHY 후보", "Evidence", "판단"],
    ["특정 Source", "주요 source에서 유사한 미도달 패턴", "설명력 낮음"],
    ["특정 Device", "desktop/mobile에서 유사한 미도달 패턴", "설명력 낮음"],
    ["단순 이탈", "scroll 87.78%, user_engagement 84.69%", "설명력 낮음"],
    ["비상품 목적", "other page 이동 2,016 / 17,711", "일부 설명"],
    ["Discovery Selection", "view_promotion 43.12%, select 0.10%", "주요 후보"],
  ], 70, 188, 705, 280, [155, 365, 185]);
  const chart = s.charts.add("bar", {
    position: { left: 825, top: 205, width: 330, height: 255 },
    categories: ["scroll", "view_promotion", "select_promotion"],
    series: [{ name: "Event rate", values: [0.8778, 0.4312, 0.0010], fill: C.coral }],
    barOptions: { direction: "column", grouping: "clustered", gapWidth: 60 },
    hasLegend: false,
    yAxis: { min: 0, max: 1, numberFormatCode: "0%", majorGridlines: { style: "solid", fill: C.line, width: 1 }, textStyle: { fontSize: 11, fill: C.muted } },
    xAxis: { textStyle: { fontSize: 10, fill: C.ink } },
  });
  applyChartFont(chart);
  note(s, "Target segment: home/other exploration -> no_view_item, n=17,711. Session share: view_promotion 43.12%, select_promotion 0.10%. 관측 데이터는 WHY candidate를 좁히는 데 사용한다.", 160, 515, 890, 72);
  addNotes(s, "Source data: docs/analysis_notes/03_home_discovery_why_hypothesis.md and sql/analysis/03_home_discovery_why.sql.");
}

// Slide 9
{
  const s = addSlide("제품 가설: Discovery 진입점 강화", "Hypothesis");
  textbox(s, "관측된 WHY 후보를 제품 가설과 실험 질문으로 변환했다.", 72, 112, 840, 42, { fontSize: 22, bold: true });
  const items = [
    ["Observed Evidence", "promotion exposure 높음\nselection 낮음\nselected session의 item_list/view_item 도달률 높음", C.blue],
    ["WHY Candidate", "Discovery exposure에서 selection으로 이어지는 전환 부족", C.coral],
    ["Product Hypothesis", "Home discovery entry point의 명확성/매력도를 높이면 Item List와 View Item 도달이 증가", C.teal],
    ["Causal Validation", "A/B test로 실제 행동 변화 검증", C.green],
  ];
  let x = 70;
  for (let i = 0; i < items.length; i += 1) {
    const [t, b, color] = items[i];
    card(s, t, b, x, 230, 250, 150, color);
    if (i < items.length - 1) addArrow(s, x + 252, 305, x + 308, 305, C.muted);
    x += 300;
  }
  note(s, "데이터로 UI 문제가 확정된 것이 아니다. 관측 근거를 검증 가능한 causal question으로 바꾼다.", 170, 470, 870, 76);
  addNotes(s, "This slide separates observational evidence from the causal question tested by the experiment.");
}

// Slide 10
{
  const s = addSlide("실험 설계: A/B 테스트 구조", "Experiment");
  textbox(s, "A/B Test는 Qualified가 아니라 treatment 이전에 정의 가능한 Home Landing 전체를 ITT로 분석한다.", 72, 110, 950, 42, { fontSize: 21, bold: true });
  addTable(s, [
    ["항목", "정의"],
    ["Eligibility Unit", "NAU first session with Home Landing"],
    ["Randomization Unit", "anonymous_id"],
    ["Analysis Unit", "eligible Home Landing first session"],
    ["Analysis Principle", "ITT, all eligible sessions included"],
  ], 78, 190, 510, 210, [190, 320]);
  const ladders = [
    ["Primary", "Home to Item List Rate", C.blue],
    ["Key Secondary", "Home to View Item Rate", C.teal],
    ["Guardrail", "Item List to View Item Rate", C.amber],
    ["Downstream", "Purchase Rate, Revenue per Session", C.coral],
  ];
  let y = 180;
  for (const [role, metric, color] of ladders) {
    card(s, role, metric, 700, y, 380, 70, color);
    y += 86;
  }
  note(s, "Qualified Home은 사후 행동으로 정의되므로 실험 eligibility로 사용하지 않는다.", 78, 470, 510, 70);
  addNotes(s, "The analysis uses Qualified Home for diagnosis, while the experiment uses all eligible Home Landing first sessions for ITT.");
}

// Slide 11
{
  const s = addSlide("실험 결과: 가상 데이터 기반 평가 파이프라인 검정", "Simulation");
  textbox(s, "Synthetic A/B에서 사전에 설정한 효과가 분석 파이프라인에서 기대 방향으로 검출되는지 확인했다.", 72, 108, 980, 42, { fontSize: 21, bold: true });
  const chart = s.charts.add("bar", {
    position: { left: 70, top: 205, width: 670, height: 310 },
    categories: ["Home to Item List", "Home to View Item", "Item List to View Item"],
    series: [
      { name: "Control", values: [0.3573, 0.2014, 0.5637], fill: C.muted },
      { name: "Treatment", values: [0.3973, 0.2268, 0.5710], fill: C.blue },
    ],
    barOptions: { direction: "column", grouping: "clustered", gapWidth: 50 },
    hasLegend: true,
    legend: { position: "bottom", textStyle: { fontSize: 12, fill: C.muted } },
    yAxis: { min: 0, max: 0.65, numberFormatCode: "0%", majorGridlines: { style: "solid", fill: C.line, width: 1 }, textStyle: { fontSize: 11, fill: C.muted } },
    xAxis: { textStyle: { fontSize: 11, fill: C.ink } },
  });
  applyChartFont(chart);
  addTable(s, [
    ["Metric", "Lift", "95% CI", "p-value"],
    ["Home to Item List", "+3.99%p", "+3.13 to +4.86", "< .001"],
    ["Home to View Item", "+2.54%p", "+1.81 to +3.28", "< .001"],
    ["Guardrail", "+0.73%p", "-0.71 to +2.18", "Pass"],
  ], 790, 205, 390, 185, [145, 70, 115, 60]);
  addTable(s, [
    ["Sample plan", "Value"],
    ["Baseline", "36.04%"],
    ["MDE", "+3.50%p"],
    ["Required sample", "2,372 per variant"],
    ["Simulation sample", "24,000 per variant"],
  ], 790, 430, 390, 170, [190, 200]);
  addNotes(s, "Synthetic data based on observed Home Landing baseline. Required sample is the minimum for MDE detection; 24,000 per variant reflects the four-week traffic scale. This simulation checks whether the analysis pipeline detects the pre-specified effect direction. Actual product impact must be validated in a production A/B test.");
}

// Slide 12
{
  const s = addSlide("매출 기회 추정: Modeled Revenue Opportunity", "Opportunity");
  textbox(s, "초기 discovery 행동 개선이 기존 downstream 전환율로 이어진다면 전체 주 매출 기준 약 2.3%의 modeled opportunity가 있다.", 72, 108, 980, 46, { fontSize: 21, bold: true });
  const flow = [
    ["11,731", "Weekly Eligible NAU Home First Sessions", C.blue],
    ["+298", "Additional View Item", C.teal],
    ["≈ 15", "Additional Purchases", C.amber],
    ["≈ $1.14K", "Revenue / week", C.green],
    ["≈ 2.3%", "of Weekly Revenue", C.coral],
  ];
  let fx = 78;
  for (let i = 0; i < flow.length; i += 1) {
    const [value, label, color] = flow[i];
    s.shapes.add({
      geometry: "rect",
      position: { left: fx, top: 225, width: 190, height: 108 },
      fill: C.white,
      line: { fill: C.line, width: 1 },
    });
    s.shapes.add({
      geometry: "rect",
      position: { left: fx, top: 225, width: 190, height: 6 },
      fill: color,
      line: { fill: "none", width: 0 },
    });
    textbox(s, value, fx + 16, 250, 158, 36, { fontSize: 25, bold: true, color });
    textbox(s, label, fx + 16, 292, 158, 28, { fontSize: 13, color: C.muted, alignment: "center" });
    if (i < flow.length - 1) {
      addArrow(s, fx + 194, 279, fx + 236, 279, C.muted);
      const multiplier = ["x 2.54%p", "x 5.1%", "x $75", "/ $49.5K"][i];
      textbox(s, multiplier, fx + 188, 245, 55, 22, { fontSize: 11, color: C.muted, alignment: "center" });
    }
    fx += 225;
  }
  addTable(s, [
    ["Step", "Calculation"],
    ["Eligible sessions", "46,923 / 4 = 11,731 per week"],
    ["Additional View Item", "11,731 x 2.54%p = 298"],
    ["Revenue opportunity", "298 x 5.1% x $75 = $1,140"],
    ["Weekly revenue share", "$1,140 / $49,477.5 = 2.3%"],
  ], 140, 398, 520, 185, [180, 340]);
  note(s, "Impact assumption: incremental View Item users keep the observed View Item to Purchase rate and revenue per purchase. This is a directional modeled opportunity, not observed revenue uplift.", 705, 414, 430, 116);
  addNotes(s, "Modeled revenue opportunity uses observed downstream baseline assumptions and should not be presented as direct revenue lift from a real production experiment.");
}

const requirements = {
  explicitTotalSlideCount: 13,
  requiredNativeTableOwnerSlides: [3, 5, 7, 9, 11, 12, 13],
  requiredNativeChartOwnerSlides: [4, 5, 6, 7, 8, 9, 12],
};

const fontPolicy = {
  basis: "design",
  families: [font],
  scriptFonts: { ea: font },
};

const candidatePath = path.join(workspaceDir, ".codex-finalizer", "ga4_portfolio_candidate.pptx");
await fs.mkdir(path.dirname(candidatePath), { recursive: true });
await (await PresentationFile.exportPptx(deck)).save(candidatePath);

await finalizePresentation({
  ...requirements,
  workspaceDir,
  candidatePath,
  finalPath,
  pythonExecutable: runtimePython,
  integrityValidatorPath: path.join(skillDir, "container_tools", "inspect_presentation_package_integrity.py"),
  layoutValidatorPath: path.join(skillDir, "container_tools", "inspect_presentation_layout_geometry.py"),
  layoutArgs: [
    "--expected-slide-size-emu",
    "12192000,6858000",
    "--validate-bullet-geometry",
    "--validate-heading-fit",
    ...requirements.requiredNativeTableOwnerSlides.flatMap((n) => ["--require-native-table-slide", String(n)]),
  ],
  requiredNativeTableOwnerSlides: requirements.requiredNativeTableOwnerSlides,
  requiredNativeChartOwnerSlides: requirements.requiredNativeChartOwnerSlides,
  materializeLiteralChartWorkbooks: true,
  fontPolicy,
  verifyArtifactToolImport: true,
  receiptPath: path.join(workspaceDir, ".codex-finalizer", "ga4_product_analytics_portfolio_v6.validation.json"),
});

console.log(finalPath);
