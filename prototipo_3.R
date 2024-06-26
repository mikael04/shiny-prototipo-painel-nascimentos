# Library ----
library(shiny)
## Layout
library(bslib)
library(gridlayout)
## Gráficos
library(ggplot2)
## Manipulação de dados
library(dplyr)
library(dbplyr)
library(tidyr)
## Comunicação com o banco de dados
library(bigrquery)
library(DBI)
## Pacote para tabelas
library(gt)
library(reactable)

## Variáveis globais ----
ggiraph_plotly <- F
taxa_nasc <- T

## Labels
label_unit <- function(max_count){
  if(max_count < 1e3){
    return("")
  }
  if(max_count >= 1e3 & max_count < 1e6){
    return("mil")
  }
  if(max_count >= 1e6 & max_count < 1e9){
    return("M")
  }
}

label_scale <- function(max_count){
  if(max_count < 1e3){
    return(1)
  }
  if(max_count >= 1e3 & max_count < 1e6){
    return(1e-3)
  }
  if(max_count >= 1e6 & max_count < 1e9){
    return(1e-6)
  }
}

## Definindo opções de idiomas para tabelas
options(reactable.language = reactableLang(
  pageSizeOptions = "\u663e\u793a {rows}",
  pageInfo = "{rowStart} \u81f3 {rowEnd} \u9879\u7ed3\u679c,\u5171 {rows} \u9879",
  pagePrevious = "\u4e0a\u9875",
  pageNext = "\u4e0b\u9875"
))

# nolint: line_length_linter.

projectid = "pdi-covid-basededados"

proj_name <- "`pdi-covid-basededados.paineis.view_sinasc_tratamento_painel`"

# Consultas iniciais ----
## UFS ----

# Set your query
sql <- paste0("SELECT DISTINCT _UF FROM ", proj_name)

# Run the query; this returns a bq_table object that you can query further
tb <- bq_project_query(projectid, sql)

ufs_f <- bq_table_download(tb) |>
  dplyr::arrange(`_UF`) |>
  dplyr::pull()

regioes_f <- c("Norte", "Nordeste", "Sudeste", "Sul", "Centro-Oeste")

# df_ufs <- data.table::fread("data-raw/pop-2022-est-ibge.csv")

## Datas ----

# Set your query
sql <- paste0("SELECT DISTINCT _ANONASC FROM ", proj_name)

# Run the query; this returns a bq_table object that you can query further
tb <- bq_project_query(projectid, sql)

anos_nasc <- bq_table_download(tb) |>
  dplyr::collect()

years_f <- anos_nasc |> dplyr::arrange(anos_nasc) |>  dplyr::pull()

cod_ibge_mun <- data.table::fread("data-raw/cod_ibge_mun_ufs.csv") |>
  dplyr::select(cod_ibge, nome_mun, uf, nome_uf)

## Variáveis para seleção ----
var_nasc_vivo <- c(#"Anomalias congênitas",
  "Apgar 1o minuto", "Apgar 5o minuto",
  "Grupo de Robson", "Idade gestacional",
  "Peso ao nascer (OMS)",
  "Raça/cor", "Sexo", "Tipo de Parto")
var_mae_nasc <- c("Escolaridade da mãe", "Estado civil da mãe", "Raça/cor da mãe")

var_all <- c(var_nasc_vivo, var_mae_nasc)
# var_sel <- c("Anomalias congênitas", "Apgar 1o minuto", "Apgar 5o minuto",
#              "Grupo de Robson", "Idade gestacional",
#              "Peso ao nascer (OMS)",
#              "Raça/cor", "Sexo", "Tipo de Parto",
#              "Escolaridade da mãe", "Estado civil da mãe",
#              "Raça/cor da mãe"
#              )
nome_var_db <- c(#"CODANOMAL",
  "APGAR1", "APGAR5", "TPROBSON", "GESTACAO", "PESO_OMS",
  "RACACOR", "PARTO", "SEXO",
  "ESCMAE2010", "ESTCIVMAE", "RACACORMAE")
df_vars_filter <- data.frame(var_all, nome_var_db)

## Variáveis para seleção bivariada ----
vars_bivariada <- c(
  "Consultas pré-natal", "Prematuridade",
  "Peso ao nascer (OMS)", "Raça/cor do nascido",
  "Sexo", "Tipo de Parto"
)
var_all_biv <- c(vars_bivariada, var_mae_nasc)
nome_var_db <- c(
  "CONSULTAS", "GESTACAO",
  "PESO", "RACACOR",
  "SEXO", "PARTO",
  "ESCMAE2010", "ESTCIVMAE", "RACACORMAE")

df_vars_filter_biv <- data.frame(var_all_biv, nome_var_db)

# UI ----
ui <- page_sidebar(
  ## CSS ----
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "style.css")
  ),
  ## Título ----
  title = "Painel de monitoramento de Nascidos Vivos",
  ## Sidebar ----
  sidebar = sidebar(
    # "sidebar",
    class = "sidebar",
    width = 350,
    # varSelectInput(
    #   "uf", "Selecione a UF",
    #   ufs_f
    # ),
    shinyWidgets::pickerInput(
      label = "Ano de referência",
      inputId = "year",
      choices = c("TODOS", years_f),
      selected = years_f[length(years_f)],
    ),
    shinyWidgets::pickerInput(
      label = "Abrangência",
      inputId = "abrang",
      choices = c("Brasil", "Região", "Unidade da federação", "Mesorregião",
                  "Microregião", "Macroregião de saúde", "Região de saúde",
                  "Município"),
      selected = "Brasil",
    ),
    uiOutput("extra_geoloc_1"),
    uiOutput("extra_geoloc_2"),
    # shinyWidgets::sliderTextInput(
    #   inputId = "date",
    #   label = "Escolha o Período:",
    #   choices = date_f,
    #   selected = date_f[c(1, length(date_f))]
    # )
    # div(
    #   class="combine_vars",
    #   shinyWidgets::pickerInput(
    #     label = "Nascimentos por",
    #     inputId = "var_sel_1",
    #     choices = list(
    #       `Variáveis de nascidos vivos` = var_nasc_vivo,
    #       `Variáveis da mãe do nascido` = var_mae_nasc
    #     )
    #   )
    # ),
    div(
      class="botao-filtros",
      shinyWidgets::actionBttn(
        inputId = "applyFilters",
        label = "Aplicar",
        style = "jelly",
        color = "primary"
      )
    )
  ),
  ## Row panel ----
  page_navbar(
    # ### Univariada ----
    # nav_panel(
    #   "Univariada",
    #   div(
    #     class="row",
    #     div(
    #       class="col-6",
    #       bslib::card(
    #         # plotOutput("mapa_2")
    #         plotOutput("barras_1")
    #       )
    #     ),
    #     div(
    #       class="col-6",
    #       bslib::card(
    #         gt::gt_output("tabela_uf")
    #       )
    #     )
    #   )
    # ),
    ### Histograma ----
    #### Nasc por área geográfica ----
    nav_panel(
      "Nascimentos por área geográfica",
      bslib::card(
        # card_header("Nascimentos", class="title-center"),
        div(
          class="row",
          bslib::card(
            layout_sidebar(
              sidebar = sidebar(
                id="sidebar_hist",
                title = "Filtros",
                position = "left", open = TRUE,
                shinyWidgets::pickerInput(
                  "Filtre por região ou UF:",
                  inputId = "filt_hist_reg_uf",
                  choices = list(
                    `Todos` = "TODOS",
                    `Regiões` = regioes_f,
                    `UFs` = ufs_f),
                  selected = "TODOS",
                ),
                shinyWidgets::pickerInput(
                  "Filtre por Raça/cor:",
                  inputId = "filt_hist_racacor",
                  choices = c("Todas", "Branca", "Preta", "Amarela", "Parda", "Indígena"),
                  selected = "Todas",
                )
              ),
              # shinycssloaders::withSpinner(ggiraph::girafeOutput("histograma")),
              shinycssloaders::withSpinner(plotly::plotlyOutput("histograma")),
              border = FALSE
            )
          )
        )
      )
    ),
    # Bivariada ----
    nav_panel(
      "Bivariada",
      div(
        class= "biv-filters",
        fluidRow(
          column(
            width = 5,
            shinyWidgets::pickerInput(
              "Selecione a primeira variável para cruzamento",
              inputId = "biv_var_1",
              choices = list(
                `Variáveis de nascidos vivos` = vars_bivariada,
                `Variáveis da mãe do nascido` = var_mae_nasc
              )
            )
          ),
          column(
            width = 5,
            shinyWidgets::pickerInput(
              "Selecione a segunda variável para cruzamento",
              inputId = "biv_var_2",
              choices = list(
                `Variáveis de nascidos vivos` = vars_bivariada,
                `Variáveis da mãe do nascido` = var_mae_nasc
              ),
              selected = "Escolaridade da mãe"
            )
          ),
          column(
            class="tabela_c_invalidos",
            width = 2,
            shinyWidgets::prettyToggle(
              inputId = "tabela_c_invalido",
              label_on = HTML("Com inválidos"),
              label_off = HTML("Sem inválidos")
            )
          )
        ),
        fluidRow(
          bslib::card(
            gt::gt_output("tabela_bivariada")
          )
        )
      )
    ),


  )
)

# Server ----
server <- function(session, input, output) {
  # Dados geográficos ----
  ## Municípios
  mun_sf <- sf::read_sf(here::here("data-raw/dados-espaciais/municipios_sf.shp"))
  ## UFs
  uf_sf <- sf::read_sf(here::here("data-raw/dados-espaciais/uf_sf.shp")) |>
    dplyr::select(cod_stt, geometry)
  ## Dados ibge municípios
  df_mun <- data.table::fread("data-raw/ibge-dados-municipais-tratados.csv")
  df_ufs <- data.table::fread("data-raw/ibge-ufs-pop-2022-est.csv")

  # Bigrquery ----
  con <- dbConnect(
    bigrquery::bigquery(),
    project = "pdi-covid-basededados",
    dataset = "paineis"
  )

  df_sinasc <- tbl(con, "view_sinasc_tratamento_painel")

  # Labels ----
  labels <- data.table::fread("data-raw/labels.csv") |>
    dplyr::select(nivel, label, variavel) |>
    dplyr::mutate(nivel = as.character(nivel))

  labels_racacor <- labels |>
    dplyr::filter(variavel == "RACACOR") |>
    dplyr::select(-variavel)

  # Valores reativos ----
  start = reactiveValues(value = TRUE)

  # Filtros reativos ----
  ## Geolocalização ----
  observeEvent(input$abrang, {
    if(input$abrang == "Brasil"){
      output$extra_geoloc_1 <- NULL
      output$extra_geoloc_2 <- NULL
    }
    if(input$abrang == "Unidade da federação"){
      output$extra_geoloc_1 <- renderUI({
        shinyWidgets::pickerInput(
          label = "Selecione a UF",
          inputId = "uf",
          choices = c("TODOS", ufs_f),
          selected = "TODOS",
        )
      })
      output$extra_geoloc_2 <- NULL
    }

    if(input$abrang == "Município"){
      output$extra_geoloc_1 <- renderUI({
        shinyWidgets::pickerInput(
          label = "Selecione a UF",
          inputId = "uf",
          choices = c(ufs_f),
          # selected = " ",
          options = list(title = "choose here")
        )
      })
      output$extra_geoloc_2 <- renderUI({
        shinyWidgets::pickerInput(
          label = "Município",
          inputId = "mun",
          choices = c("Selecione a UF")
        )
      })
    }
  })
  observeEvent(input$uf,{
    if(input$uf != " "){
      muns_uf_sel <- cod_ibge_mun |>
        dplyr::filter(uf == input$uf) |>
        dplyr::arrange(nome_mun, .locale = "pt_BR") |>
        dplyr::pull(nome_mun)

      shinyWidgets::updatePickerInput(
        session = session, inputId = "mun",
        choices = muns_uf_sel
      )
    }
  })

  observeEvent(input$cmp_var, {
    if(input$cmp_var){
      output$extra_var <- renderUI({
        shinyWidgets::pickerInput(
          label = "Selecione uma variável para cruzamento",
          inputId = "var_sel_2",
          choices = c("Idade da mãe", "Escolaridade da mãe", "C"),
        )
      })
    }else{
      output$extra_var <- NULL
    }
  })

  ## Dados iniciais ----

  # browser()

  ## Histograma c/ seletor ----
  ### Separando dados por filtros ----
  #### Com UF, será filtrado o df que faz o join
  df_ufs_f <- reactive({
    if(input$filt_hist_reg_uf == "TODOS"){
      df_ufs_f <- df_ufs
    }
    if(input$filt_hist_reg_uf %in% regioes_f){
      df_ufs_f <- df_ufs |>
        dplyr::filter(uf_reg == input$filt_hist_reg_uf)
    }
    if(input$filt_hist_reg_uf %in% ufs_f){
      df_ufs_f <- df_ufs |>
        dplyr::filter(uf_sigla == input$filt_hist_reg_uf)
    }
    df_ufs_f
  })

  #### Com racacor filtraremos a base original
  df_sinasc_f <- reactive({
    # browser()

    ## Contagem de nascimentos por estados e por data (ano_nasc)
    df_sinasc_ufs_nasc <- df_sinasc  |>
      # dplyr::filter(RACACOR != "0" && RACACOR != "") |>
      dplyr::group_by(`_UF`, `_ANONASC`, RACACOR) |>
      dplyr::summarise(count = n()) |>
      dplyr::select(uf_cod = `_UF`, ano_nasc = `_ANONASC`, racacor = RACACOR, count) |>
      dplyr::ungroup() |>
      dplyr::collect()

    df_sinasc_ufs_nasc <- df_sinasc_ufs_nasc |>
      dplyr::mutate(racacor = dplyr::case_when(
        racacor == 1 ~ "Branca",
        racacor == 2 ~ "Preta",
        racacor == 3 ~ "Amarela",
        racacor == 4 ~ "Parda",
        racacor == 5 ~ "Indígena",
        TRUE ~ "Ignorado/Inválido"))

    if(input$filt_hist_racacor == "Todas"){
      df_sinasc_ufs_nasc <- df_sinasc_ufs_nasc
    }
    if(input$filt_hist_racacor != "Todas"){
      df_sinasc_ufs_nasc <- df_sinasc_ufs_nasc |>
        dplyr::filter(racacor == input$filt_hist_racacor)
    }
    df_sinasc_ufs_nasc
  })


  # Criar um output shiny do tipo ggiraph com um gráfico de histograma
  ### Histograma output ----
  # output$histograma <- ggiraph::renderGirafe({
  output$histograma <- plotly::renderPlotly({
    df_sinasc_ufs_nasc <- dplyr::inner_join(df_ufs_f(), df_sinasc_f(),
                                            by=c("uf_sigla" = "uf_cod")) |>
      dplyr::mutate(taxa_nasc = 1000 * count / populacao)
    # browser()

    # browser()
    ## Crie um gráfico de histograma com os dados de df_sinasc_ufs_nasc, agrupando por ano_nasc
    ## e contando o número de linhas
    ## Se região, apresentar diferentes linhas por UF
    if(input$filt_hist_reg_uf %in% regioes_f){
      ## Calculando por taxa de nascimentos por mil habitantes
      if(taxa_nasc){
        df_sinasc_ufs_nasc_hist <- df_sinasc_ufs_nasc |>
          dplyr::group_by(ano_nasc, uf_sigla) |>
          dplyr::summarise(count = sum(taxa_nasc)) |>
          dplyr::ungroup()
      }
      if(!taxa_nasc){
        df_sinasc_ufs_nasc_hist <- df_sinasc_ufs_nasc |>
          dplyr::group_by(ano_nasc, uf_sigla) |>
          dplyr::summarise(count = sum(count)) |>
          dplyr::ungroup()
      }

      title <- paste0("Taxa de Nascimentos por ano (por mil nascidos vivos)", " - Região: ", input$filt_hist_reg_uf)
      subtitle_add_racacor <- ifelse(input$filt_hist_racacor == "Todas", "",
                                     paste0(" - Raça/cor: ", input$filt_hist_racacor))
      subtitle <- paste0("Agrupados por UF", subtitle_add_racacor)

      max_count <- max(df_sinasc_ufs_nasc_hist$count)

      # Crie um gráfico de histograma do tipo ggiraph com os dados de df_sinasc_ufs_nasc_hist
      # usando os dados de ano_nasc e count como tooltip
      graph_hist <- df_sinasc_ufs_nasc_hist |>
        ggplot2::ggplot(aes(x = ano_nasc, y = count, group = uf_sigla, color = uf_sigla,
                            text = paste0("Ano: ", ano_nasc, "\n",
                                          "UF: ", uf_sigla, "\n",
                                          "Taxa de Nascimento (por mil): ", "\n", round(count, 2)))) +
        ggplot2::labs(title = title,
                      subtitle = subtitle,
                      x = "",
                      y = "") +
        ggplot2::labs(color = "UFs:") +
        ggplot2::scale_x_discrete(breaks = seq(1996, 2024, 2)) +
        ggplot2::scale_y_continuous(limits = c(0, NA),
                                    labels = scales::unit_format(unit = label_unit(max_count), scale = label_scale(max_count))) +
        ggplot2::theme_minimal() +
        ggplot2::geom_line()

        # ggiraph::geom_line_interactive(aes(x = ano_nasc, y = count, group = uf_sigla, color = uf_sigla,
        #                                    tooltip = paste0("Ano: ", ano_nasc, "<br> UF: ", uf_sigla,
        #                                                     "<br> Nascimentos: ", count, ifelse(input$filt_hist_racacor == "Todas", "",
        #                                                                                         paste0("<br> Raça/cor: ", input$filt_hist_racacor)))))
      # ggiraph::geom_bar_interactive(stat = "identity", width = 1, fill = "#ABA2D1",
        #                               aes(x = ano_nasc, y = count, tooltip = paste0("Ano: ", ano_nasc, "<br> Nascimentos: ", count)))


      # ggiraph::girafe(ggobj = graph_hist, width_svg = 6, height_svg = 4)
    }
    ## Se não for região, apresentar diferentes linhas por UF selecionada + raca/cor
    if(input$filt_hist_reg_uf %in% ufs_f || input$filt_hist_reg_uf == "TODOS"){
      ## Calculando por taxa de nascimentos por mil habitantes
      if(taxa_nasc){
        df_sinasc_ufs_nasc_hist <- df_sinasc_ufs_nasc |>
          dplyr::group_by(ano_nasc, racacor) |>
          dplyr::summarise(count = sum(taxa_nasc)) |>
          dplyr::ungroup()
      }
      ## Calculando por taxa de nascimentos por mil habitantes
      if(!taxa_nasc){
        df_sinasc_ufs_nasc_hist <- df_sinasc_ufs_nasc |>
          dplyr::group_by(ano_nasc, racacor) |>
          dplyr::summarise(count = sum(count)) |>
          dplyr::ungroup()
      }

      title <- "Taxa de Nascimentos por ano (por mil nascidos vivos)"
      title_add <- ifelse(input$filt_hist_reg_uf == "TODOS", " - Brasil", paste0(" - UF: ", input$filt_hist_reg_uf))
      title <- paste0(title, title_add)

      subtitle <- paste0("Agrupados por raça/cor")

      max_count <- max(df_sinasc_ufs_nasc_hist$count)

      # labels_racacor <- labels |>
      #   dplyr::filter(variavel == "RACACOR") |>
      #   dplyr::mutate(nivel = as.character(nivel))
      #
      # df_sinasc_ufs_nasc_hist <- inner_join(df_sinasc_ufs_nasc_hist, labels_racacor,
      #                                       by = c("racacor" = "nivel")) |>
      #   dplyr::select(-racacor, -variavel) |>
      #   dplyr::rename(racacor = label)

      # browser()
      # Crie um gráfico de histograma do tipo ggiraph com os dados de df_sinasc_ufs_nasc_hist
      # usando os dados de ano_nasc e count como tooltip
      graph_hist <- df_sinasc_ufs_nasc_hist |>
      # df_sinasc_ufs_nasc_hist |>
        ggplot2::ggplot(aes(x = ano_nasc, y = count, group = racacor, color = racacor,
                            text = paste0("Ano: ", ano_nasc, "\n",
                                          "Raça/cor: ", racacor, "\n",
                                          "Taxa de Nascimento (por mil): ", "\n", round(count, 2)))) +
        ggplot2::labs(title = title,
                      subtitle = subtitle,
                      x = "",
                      y = "",
                      color = "Raça/Cor:") +
        ggplot2::theme_minimal() +
        ggplot2::scale_y_continuous(limits = c(0, NA),
                                    labels = scales::unit_format(unit = label_unit(max_count), scale = label_scale(max_count))) +
        ggplot2::scale_x_discrete(breaks = seq(1996, 2024, 2))  +
        ggplot2::geom_line() +
        # ggiraph::geom_line_interactive(aes(x = ano_nasc, y = count, group = racacor, color = racacor,
        #                                    tooltip = paste0("Ano: ", ano_nasc, "<br> Raça/cor: ", racacor,
        #                                                     "<br> Nascimentos: ", count))) +
        ## Adicionando cor às raça/cor
        ggplot2::scale_color_manual(values = c("Branca" = "lightgray", "Preta" = "black",
                                              "Amarela" = "#FFE033", "Parda" = "#BB9157",
                                              "Indígena" = "#008000", "Ignorado/Inválido" = "orange"))
        # ggplot2::geom_line(aes(x = ano_nasc, y = count, group = racacor, color = racacor))
      # ggiraph::geom_bar_interactive(stat = "identity", width = 1, fill = "#ABA2D1",
      #                               aes(x = ano_nasc, y = count, tooltip = paste0("Ano: ", ano_nasc, "<br> Nascimentos: ", count)))


      # # graph_hist
      # ggiraph::girafe(ggobj = graph_hist, width_svg = 8, height_svg = 4)
      # plotly::ggplotly(graph_hist, tooltip = "text") |>
      #   plotly::config(modeBarButtonsToRemove = c("zoom2d", "pan2d", "autoScale", "hoverCompare", "toggleHover"))

    }
    # graph_hist
    # ggiraph::girafe(ggobj = graph_hist, width_svg = 8, height_svg = 4)
    # browser()
    plotly::ggplotly(graph_hist, tooltip = "text") |>
      plotly::config(modeBarButtonsToRemove = c("zoom2d", "pan2d", "autoScale", "hoverCompare", "toggleHover"))


  })

  # Bivariada ----

  ### Separando dados por filtros ----
  #### Com UF, será filtrado o df que faz o join
  df_sinasc_biv <- reactive({
    year <- input$year
    browser()
    if(year != "TODOS"){
      df_sinasc_filt <- df_sinasc |>
        dplyr::filter(`_ANONASC` == year)
    }

    # browser()
    #### Brasil ----
    if(input$abrang == "Brasil"){
      df_sinasc_filt <- df_sinasc_filt
    }
    #### UF ----
    if(input$abrang == "Unidade da federação"){
      if(input$uf == "TODOS"){
        df_sinasc_filt <- df_sinasc_filt
      }else{
        df_sinasc_filt <- df_sinasc_filt |>
          dplyr::filter(`_UF` == input$uf)
      }
    }
    #### Município ----
    if(input$abrang == "Município"){
      if(input$mun == "Selecione a UF"){
        df_sinasc_filt <- df_sinasc_filt
      }else{
        df_sinasc_filt <- df_sinasc_filt |>
          dplyr::filter(cod_mun == input$mun)
      }
    }
    df_sinasc_filt |>
      dplyr::select(all_of(nome_var_db))
  })

  ### Tabela bivariada ----
  #### Filtrando variáveis selecionadas ----
  df_sinasc_biv_vars <- reactive({
    # browser()

    ## Definindo variáveis selecionadas
    df_var1 <- df_vars_filter_biv |>
      dplyr::filter(var_all_biv == input$biv_var_1)

    var1_name <- df_var1 |>
      dplyr::pull(var_all_biv)

    var1 <- df_var1 |>
      dplyr::pull(nome_var_db)

    df_var2 <- df_vars_filter_biv |>
      dplyr::filter(var_all_biv == input$biv_var_2)

    var2_name <- df_var2 |>
      dplyr::pull(var_all_biv)

    var2 <- df_var2 |>
      dplyr::pull(nome_var_db)

    ## Separando dados por filtros selecionadas
    df_sinasc_biv <- df_sinasc_biv()

    # browser()

    ## Selecionando variáveis e criando dados de contagem por variáveis selecionadas
    df_sinasc_biv_vars_filt <- df_sinasc_biv |>
      dplyr::select(!as.name(var1), !as.name(var2)) |>
      dplyr::group_by(!!as.name(var1), !!as.name(var2)) |>
      dplyr::summarise(count = n()) |>
      dplyr::ungroup() |>
      dplyr::collect()

    ## Labels de variáveis selecionadas
    labels_var1 <- labels |>
      dplyr::filter(variavel == var1) |>
      dplyr::select(-variavel) |>
      dplyr::rename(!!var1 := nivel)

    labels_var2 <- labels |>
      dplyr::filter(variavel == var2) |>
      dplyr::select(-variavel) |>
      dplyr::rename(!!var2 := nivel)

    ## Adicionando labels
    df_sinasc_biv_vars_filt_lab <- df_sinasc_biv_vars_filt |>
      dplyr::left_join(labels_var1) |>
      dplyr::select(-!!as.name(var1), label) |>
      # dplyr::mutate(CONSULTAS = ifelse(is.na(CONSULTAS), "99", CONSULTAS))
      dplyr:::mutate(label = ifelse(is.na(label), "Inválido ou nulo", label)) |>
      dplyr::rename(!!var1 := label) |>
      dplyr::left_join(labels_var2) |>
      dplyr:::mutate(label = ifelse(is.na(label), "Inválido ou nulo", label)) |>
      dplyr::select(-!!var2, var2 = label) |>
      dplyr::select(!!as.name(var1), var2, count) |>
      dplyr::group_by(!!as.name(var1), var2) |>
      dplyr::summarise(count = sum(count)) |>
      dplyr::ungroup()

    ### Com inválido na tabela e soma de totais (com inválido) ----
    if(input$tabela_c_invalido){
      ## Não utilizar mais a linha de total
      # df_sinasc_biv_vars_filt_lab_total <- df_sinasc_biv_vars_filt_lab |>
      #   dplyr::group_by(var2) |>
      #   dplyr::summarise(count = sum(count)) |>
      #   dplyr::ungroup() |>
      #   dplyr::mutate(!!as.name(var1) := "Total") |>
      #   dplyr::select(!!as.name(var1), var2, count) |>
      #   dplyr::bind_rows(df_sinasc_biv_vars_filt_lab)

      ## Removendo apenas a linha de inválido ou nulo
      df_sinasc_biv_vars_filt_lab <- df_sinasc_biv_vars_filt_lab |>
        dplyr::filter(!!as.name(var1) != "Inválido ou nulo")

      df_sinasc_biv_vars_filt_lab_wider <- df_sinasc_biv_vars_filt_lab |>
        tidyr::pivot_wider(names_from = var2, values_from = count, names_sort = FALSE)

      df_sinasc_biv_col_invalid <- df_sinasc_biv_vars_filt_lab_wider |>
        dplyr::select(`Inválido ou nulo`)

      # sum(df_sinasc_biv_vars_filt_lab_wider[1, 2:7], na.rm = TRUE)
      # sum(df_sinasc_biv_vars_filt_lab_wider$Total, na.rm = TRUE)
      # sum_total <- df_sinasc_biv_vars_filt_lab_wider[-1, 1]
      # sum_total <- df_sinasc_biv_vars_filt_lab_wider[1, 2:7]

      df_sinasc_biv_vars_filt_lab_wider <- df_sinasc_biv_vars_filt_lab_wider |>
        dplyr::select(-`Inválido ou nulo`) |>
        dplyr::mutate(Total = rowSums(across(-!!as.name(var1))))

    }
    if(!input$tabela_c_invalido){
      ### Sem inválido na tabela e soma de totais (com inválido)
      df_sinasc_biv_vars_filt_lab_val <- df_sinasc_biv_vars_filt_lab |>
        dplyr::filter(!!as.name(var1) != "Inválido ou nulo",
                      var2 != "Inválido ou nulo")

      ## Não vou mais usar a linha de total, só a coluna
      # df_sinasc_biv_vars_filt_lab_val_total <- df_sinasc_biv_vars_filt_lab_val |>
      #   dplyr::group_by(var2) |>
      #   dplyr::summarise(count = sum(count)) |>
      #   dplyr::ungroup() |>
      #   dplyr::mutate(!!as.name(var1) := "Total") |>
      #   dplyr::select(!!as.name(var1), var2, count) |>
      #   dplyr::bind_rows(df_sinasc_biv_vars_filt_lab_val)


      df_sinasc_biv_vars_filt_lab_wider <- df_sinasc_biv_vars_filt_lab_val |>
        tidyr::pivot_wider(names_from = var2, values_from = count, names_sort = FALSE) |>
        dplyr::mutate(Total = rowSums(across(-!!as.name(var1))))
    }

    ## Recebendo numa nova tabela os dados no formato wide
    tabela_bivariada <- df_sinasc_biv_vars_filt_lab_wider

    ## Ordenando colunas da segunda variável
    new_order <- c(var1, labels_var2$label)
    new_order <- c(new_order[new_order != "Inválido ou nulo"], "Total")

    ## Removendo colunas que não aparecem (por não terem dados)
    # browser()
    # if(length(new_order) != ncol(tabela_bivariada)){
    #   new_oder <- new_order[new_order %in% colnames(tabela_bivariada)]
    # }

    ## Reordenando e organizando a ordem
    tabela_bivariada <- tabela_bivariada |>
      dplyr::select(!!new_order) |>
      dplyr::arrange(factor(!!as.name(var1), levels = labels_var1$label))

    #### Calculando percentuais ----
    tabela_bivariada_perc <- tabela_bivariada |>
      mutate(across(-CONSULTAS, ~ round(.x / Total, 4), .names = "{.col}_%"))

    ## Reordenando vetor, com novas colunas de percentual
    cols_with_perc <- colnames(tabela_bivariada_perc)
    new_order_perc <- new_order[1]
    final_col_names <- var1_name

    ## Criando vetor de ordenação e nome das colunas com percentual
    for(i in 2:length(new_order)){
      new_order_perc <- c(new_order_perc, paste0(cols_with_perc[i]),
                          cols_with_perc[i+length(new_order)-1])
      final_col_names <- c(final_col_names, paste0(cols_with_perc[i], "_N"),
                           cols_with_perc[i+length(new_order)-1])
    }

    tabela_bivariada_perc <- tabela_bivariada_perc |>
      dplyr::select(!!new_order_perc)

    tab_biv_final <- tabela_bivariada_perc
    colnames(tab_biv_final) <- final_col_names

    ## Adicionando coluna de inválido, no caso de tabela com inválido
    if(input$tabela_c_invalido){
      tab_biv_final <- bind_cols(tab_biv_final, df_sinasc_biv_col_invalid)
    }

    tab_biv_final
  })

  ## Criar uma tabela gt de output com os dados de df_sinasc_apgar_idade_wide
  output$tabela_bivariada <- gt::render_gt({

    tab_biv_final <- df_sinasc_biv_vars()
    # browser()

    df_var1 <- df_vars_filter_biv |>
      dplyr::filter(var_all_biv == input$biv_var_1)

    var1_name <- df_var1 |>
      dplyr::pull(var_all_biv)

    df_var2 <- df_vars_filter_biv |>
      dplyr::filter(var_all_biv == input$biv_var_2)

    var2_name <- df_var2 |>
      dplyr::pull(var_all_biv)

    title <- paste0("Contagem de ", var1_name, " por ", var2_name)
    gt_table <- tab_biv_final |>
      gt::gt(locale = "pt") |>
      gt::tab_header(title = title, subtitle = var2_name, preheader = NULL) |>
      gt::tab_style(
        style = list(
          cell_text(weight = "bold")
        ),
        locations = cells_body(
          columns = c("Total_N", "Total_%")
        )
      ) |>
      # gt::opt_interactive(use_compact_mode = TRUE) |>
      gt::tab_spanner_delim(
        delim = "_"
      ) |>
      fmt_percent(ends_with("%"), decimals = 2)
      # gt::cols_label(
      #   !!var1 := var1_name,
      #   Total = md("**Total**")
      # ) |>
      # gt::tab_style(
      #   style = list(
      #     cell_text(weight = "bold")
      #   ),
      #   locations = cells_body(
      #     rows = nrow(tab_biv_final)
      #   )
      # )

    if(input$tabela_c_invalido){
      gt_table <- gt_table |>
        gt::cols_move_to_end(columns = "Inválido ou nulo") |>
        gt::tab_style(
          style = list(
            cell_text(weight = "lighter", color = "darkgrey")
          ),
          locations = cells_body(
            columns = "Inválido ou nulo"
          )
        )
    }

    gt_table
  })


}

shinyApp(ui, server)
