suppressPackageStartupMessages(library(googleVis))
#library(rmarkdown)
library(dplyr, warn.conflicts = FALSE)
library(magrittr)

options(shiny.sanitize.errors = TRUE)

function(input, output, session) {
  # Validate inputs and set defaults ----

  # Birthday
  Birthdate <- reactive({
    validate(need(input$Birthdate, VM$Birthdate))
    validate(need(calcAge(input$Birthdate) < RetirementAge(), VM$Birthdate2))
    input$Birthdate
  })

  # Gender
  gender <- reactive({
    validate(need(input$gender, VM$gender))
    input$gender
  })

  # Mirai Colors
  miraiColors <- "['#008cc3', '#FF9966', '#13991c']"

  # Retirement Age
  RetirementAge <- reactive({

    val <- max(min(isnotAvailableReturnZero(input$RetirementAge), value$max_retirement), value$min_retirement)
    if (!is.na(input$RetirementAge) && input$RetirementAge != val) {
      updateNumericInput(session, "RetirementAge", value = val)
    }

    if (input$provideRetirementAge) {
      validate(need(input$RetirementAge, VM$RetirementAge))
      min(value$max_retirement, input$RetirementAge)
    } else {
      if (gender() == "M") {
        value$retirement_male
      } else {
        value$retirement_female
      }
    }
  }) %>% debounce(millis = 100)

  observeEvent(input$gender, {
    if (gender() == "F") {
      updateNumericInput(session, "RetirementAge", value = value$retirement_female)
    } else {
      updateNumericInput(session, "RetirementAge", value = value$retirement_male)
    }
  })

  # 3rd Pillar ----
  # default option 0
  CurrentP3_notZero <- reactive({
    isnotAvailableReturnZero(input$CurrentP3)
  })

  CurrentP3 <- reactive({
    update_neg("CurrentP3", session)

    if (P3purchase() == 0 &
        Salary() == 0 & CurrentP2() == 0 & P2purchase() == 0) {
      validate(
        need_not_zero(
          CurrentP3_notZero(),
          VM$CurrentP3_CurrentP2_Salary_Purchases_notZero
        )
      )
      CurrentP3_notZero()
    } else {
      CurrentP3_notZero()
    }
  })

  P3purchase <- reactive({
    update_neg("P3purchase", session)
    isnotAvailableReturnZero(input$P3purchase)
  })

  returnP3_notzero <- reactive({
    isnotAvailableReturnZero(input$returnP3 / 100)
  })

  returnP3 <- reactive({
    update_neg("returnP3", session)

    if (CurrentP3() == 0 &
        P3purchase() == 0 &
        Salary() == 0 & CurrentP2() == 0 & P2purchase() == 0) {
      validate(
        need_not_zero(
          returnP3_notzero(),
          VM$CurrentP3_CurrentP2_Salary_Purchases_notZero
        )
      )
      returnP3_notzero()
    } else {
      returnP3_notzero()
    }
  })


  # Tax info ----
  TaxRelief <- reactive({
    if (input$rate_group == "C") {
      MaxContrTax * 2
    } else {
      MaxContrTax
    }
  })

  # Postal Code / Gemeinden
  selPLZGemeinden <- reactive({
    validate(need(input$plzgemeinden, VM$plzgemeinden))
    PLZGemeinden[match(input$plzgemeinden, PLZGemeinden$PLZGDENAME), ]
  })
  postalcode <- reactive({
    selPLZGemeinden()$PLZ
  })
  gemeinden <- reactive({
    selPLZGemeinden()$GDENAME
  })

  # Number of kids (max = 9)
  NChildren <- reactive({
    val <- max(min(isnotAvailableReturnZero(input$NChildren), value$max_children), 0)
    if (!is.na(input$NChildren) && input$NChildren != val) {
      updateNumericInput(session, "NChildren", value = val)
    }
    val
  }) %>% debounce(millis = 100)

  # Tariff
  rate_group <- reactive({
    validate(need(input$rate_group, VM$rate_group))
    input$rate_group
  })

  # Church taxes
  churchtax <- reactive({
    if (input$churchtax == "A") {
      "Y"
    } else {
      "N"
    }
  })

  # Salary
  Salary <- reactive({
    val <- max(min(isnotAvailableReturnZero(input$Salary), value$max_salary), 0)
    if (!is.na(input$Salary) && input$Salary != val) {
      updateNumericInput(session, "Salary", value = val)
    }
    val
  }) %>% debounce(millis = 100)

  SalaryGrowthRate <- reactive({
    update_neg("SalaryGrowthRate", session)
    isnotAvailableReturnZero(input$SalaryGrowthRate / 100)
  })

  # 2nd Pillar
  CurrentP2 <- reactive({
    update_neg("CurrentP2", session)
    isnotAvailableReturnZero(input$CurrentP2)
  })

  P2interestRate <- reactive({
    val <- value$min_p2_interest
    if (!is.na(input$P2interestRate) && input$P2interestRate < val) {
      updateNumericInput(session, "P2interestRate", value = val)
    }
    isnotAvailableReturnZero(input$P2interestRate / 100)
  })

  P2purchase <- reactive({
    update_neg("P2purchase", session)
    isnotAvailableReturnZero(input$P2purchase)
  })

  TypePurchase <- reactive({
    validate(need(input$TypePurchase, VM$TypePurchase))
    input$TypePurchase
  })


  # calc P2 fund ----
  ContributionP2Path <- reactive({
    buildContributionP2Path(
      birthday = Birthdate(),
      Salary = Salary(),
      SalaryGrowthRate = SalaryGrowthRate(),
      CurrentP2 = CurrentP2(),
      P2purchase = P2purchase(),
      TypePurchase = TypePurchase(),
      rate = P2interestRate(),
      givenday = lubridate::today("UTC"),
      RetirementAge = RetirementAge()
    )
  })

  # calc P3 fund ----
  ContributionP3path <- reactive({
    buildContributionP3path(
      birthday = Birthdate(),
      P3purchase = P3purchase(),
      CurrentP3 = CurrentP3(),
      returnP3 = returnP3(),
      RetirementAge = RetirementAge()
    )
  })

  # calc Tax benefits ----
  ContributionTaxpath <- reactive({
    buildTaxBenefits(
      birthday = Birthdate(),
      TypePurchase = TypePurchase(),
      P2purchase = P2purchase(),
      P3purchase = P3purchase(),
      returnP3 = returnP3(),
      Salary = Salary(),
      SalaryGrowthRate = SalaryGrowthRate(),
      postalcode = postalcode(),
      NChildren = NChildren(),
      churchtax = churchtax(),
      rate_group = rate_group(),
      givenday = lubridate::today("UTC"),
      RetirementAge = RetirementAge()
    )
  })

  # build Road2Retirement ----
  Road2Retirement <- reactive({
    ContributionP2Path() %>%
      left_join(ContributionP3path(), by = c("Calendar", "t")) %>%
      left_join(ContributionTaxpath(), by = c("Calendar", "t", "AgePath")) %>%
      mutate(Total = TotalP2 + TotalP3 + TotalTax)
  })

  # Table ----
  output$table <- renderTable({
    makeTable(Road2Retirement = Road2Retirement())
  }, digits = 0, align = "r")

  # T series plot ----
  TserieGraphData <- reactive({
    Road2Retirement() %>%
      mutate(`Tax Benefits` = TotalTax) %>%
      mutate(`2nd Pillar` = DirectP2 + ReturnP2) %>%
      mutate(`3rd Pillar` = DirectP3 + ReturnP3) %>%
      select(Calendar,
             `2nd Pillar`,
             `3rd Pillar`,
             `Tax Benefits`) %>%
      .[, colSums(. != 0, na.rm = TRUE) > 0]
  })

  output$plot_t <- renderGvis({
    gvisAreaChart(
      chartid = "plot_t",
      data = TserieGraphData(),
      xvar = "Calendar",
      yvar = colnames(TserieGraphData())[which(colnames(TserieGraphData()) != "Calendar")],
      options = list(
        chartArea = "{left: '18.75%', width: '68.75%'}",
        isStacked = TRUE,
        legend = "bottom",
        colors = miraiColors
      )
    )
  })

  # Bar plot -----
  FotoFinish <- reactive({
    Road2Retirement() %>%
      mutate(`Tax Benefits` = TotalTax) %>%
      mutate(`2nd Pillar` = DirectP2 + ReturnP2) %>%
      mutate(`3rd Pillar` = DirectP3 + ReturnP3) %>%
      select(`2nd Pillar`, `3rd Pillar`, `Tax Benefits`) %>%
      tail(1) %>%
      prop.table() %>%
      select_if(function(x)
        x != 0)
  })


  BarGraphData <- reactive({
    cbind(FotoFinish(), FotoFinish()) %>%
      set_colnames(c(colnames(FotoFinish()), paste0(
        colnames(FotoFinish()), ".annotation"
      ))) %>%
      mutate(contribution = "") %>%
      changeToPercentage() %>%
      .[, order(colnames(.))]
  })

  output$plot_final <- renderGvis({
    gvisBarChart(
      chartid = "plot_final",
      data = BarGraphData(),
      xvar = "contribution",
      yvar = colnames(BarGraphData())[!grepl("contribution", colnames(BarGraphData()))],
      options = list(
        chartArea = "{left: '18.75%', width: '68.75%'}",
        isStacked = TRUE,
        vAxes = "[{minValue:0}]",
        hAxis = "{format:'#,###%'}",
        legend = "none",
        colors = miraiColors,
        dataOpacity = 0.3,
        bar = "{groupWidth: '100%'}",
        annotations = "{highContrast: 'false', textStyle: {bold: true}}"

      )
    )
  })

  # build Totals statement ----
  retirementdate <- reactive({
    getRetirementday(Birthdate(), RetirementAge())
  })

  retirementfund <- reactive({
    Road2Retirement()[, "Total"] %>%
      tail(1) %>%
      as.integer()
  })

  lastSalary <- reactive({
    Road2Retirement()[, "ExpectedSalaryPath"] %>%
      tail(1) %>%
      as.integer()
  })

  percentageLastSalary <- reactive({
    if (lastSalary() != 0) {
      numTimes <- retirementfund() / lastSalary()
      numTimes %<>% formatC(format = "f", digits = 2)
      paste(numTimes, "times the last salary")
    } else {
      ""
    }
  })

  output$Totals <- renderText({
    paste0(
      "Total retirement fund as of ",
      format(retirementdate(), "%d-%m-%Y"), ": ",
      formatC(
        retirementfund() / 1000,
        format = "f",
        big.mark = ",",
        digits = 0,
        decimal.mark = "."
      ),
      "k ",
      "(", percentageLastSalary(), ")"
    )
  })


  # Output Report ----

  # params list to be passed to the output
  params <- reactive(
    list(
      Salary = Salary(),
      birthday = Birthdate(),
      Road2Retirement = Road2Retirement(),
      SalaryGrowthRate = SalaryGrowthRate(),
      CurrentP2 = CurrentP2(),
      P2purchase = P2purchase(),
      TypePurchase = TypePurchase(),
      rate = P2interestRate(),
      P3purchase = P3purchase(),
      CurrentP3 = CurrentP3(),
      returnP3 = returnP3(),
      postalcode = postalcode(),
      gemeinden = gemeinden(),
      Kanton = returnPLZKanton(postalcode()),
      NChildren = NChildren(),
      churchtax = churchtax(),
      rate_group = rate_group(),
      MaxContrTax = TaxRelief(),
      retirementdate = retirementdate(),
      BarGraphData = BarGraphData(),
      TserieGraphData = TserieGraphData(),
      RetirementAge = RetirementAge(),
      TaxRate = NULL,
      retirementfund = retirementfund(),
      percentageLastSalary = percentageLastSalary(),
      PLZGemeinden = PLZGemeinden,
      AHL = AHL,
      ALV = ALV,
      VersicherungsL = VersicherungsL,
      VersicherungsV = VersicherungsV,
      VersicherungsK = VersicherungsK,
      DOV = DOV,
      Kinder = Kinder,
      Verheiratet = Verheiratet
    )
  )

  # build report name
  reportname <- reactive(
    paste("SmaRPreport", format(Sys.Date(), "%Y%m%d"), "pdf", sep= ".")
  )

  # generate output report
  output$report <- downloadHandler(
    filename = reportname(),
    content = function(file) {
      withModalSpinner(
        rmarkdown::render(
          input = "report.Rmd",
          output_file = file,
          output_format = "pdf_document",
          # output_format = "html_document",
          params = params(),
          envir = new.env(parent = globalenv()) # sharing data only via params
        ),
        "Generating the report...", size = "s"
      )
    }
  ) # end of downloadHandler

  # build report name
  dataname <- reactive(
    paste("SmaRPdata", format(Sys.Date(), "%Y%m%d"), "csv", sep= ".")
  )

  # generate output data
  output$data_download <- downloadHandler(
    filename = dataname(),
    content = function(file) {
      write.csv((Road2Retirement = Road2Retirement() %>%
                   select(Calendar,
                          ExpectedSalaryPath,
                          BVGcontributionrates,
                          BVGContributions,
                          BVGpurchase,
                          DirectP2,
                          ReturnP2,
                          TotalP2,
                          P3ContributionPath,
                          P3purchase,
                          DirectP3,
                          ReturnP3,
                          TotalP3,
                          DirectTax,
                          ReturnTax,
                          TotalTax,
                          Total)),
                file,
                row.names = FALSE)
    }
  ) # end of downloadHandler

  # refresh inputs ----
  # Refresh plz-gemeinde correspondance
  # when the value of input$refreshButton becomes out of date
  # (i.e., when the button is pressed)
  refreshText <- eventReactive(input$refreshButton, {
    downloadInputs(refresh = TRUE)
  })

  output$refreshText <- renderText({
    paste(as.character(refreshText()))
  })

}
