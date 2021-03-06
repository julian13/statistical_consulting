
server <- function(input, output, session) {
  
  # set global data used by the app
  
  hideTab(inputId="tabs",target="Table")
  hideTab(inputId="tabs",target="Reference Element Comparison")
  hideTab(inputId="tabs",target="Overview Table")
  hideTab(inputId="tabs",target="Baseline Calibration")
  hideTab(inputId="tabs",target="Calibration Curve")
  
  calibration_sites=F
  clean_sites = calibration.env$clean_sites
  clean_sites_normalized = calibration.env$clean_sites_normalized
  dirty_sites = calibration.env$dirty_sites
  #create the map
  output$mymap <- renderLeaflet({
    leaflet() %>% 
      setView(lng = -118.16, lat = 33.75, zoom = 7) %>% #setting the view over ~ center of bight
      addProviderTiles(providers$CartoDB.Positron)
  })

  #####################################
  # Reference Metals Overview pageset
  ######################################
  observeEvent(input$rm_button,{
    hideTab(inputId="tabs",target="Table")
    hideTab(inputId="tabs",target="Reference Element Comparison")
    hideTab(inputId="tabs",target="Calibration Curve")
    showTab(inputId="tabs",target="Overview Table")
    hideTab(inputId="tabs",target="Baseline Calibration")
    reference=input$reference_metal
    
    calibration_sites = input$debug_mode

    if(input$debug_mode){
      site_used = clean_sites
    } else {
      site_used = dirty_sites
    }



            pal <- colorNumeric(

      palette = c("blue"),
      na.color = "red",
      domain = clean_sites[clean_sites$ReferenceMetal==reference,][["PPH"]])
    
    proxy <- leafletProxy("mymap")
    
    proxy %>% setView(lng = -118.16, lat = 33.75, zoom = 7)  %>% #setting the view over ~ center of bight
      clearMarkers() %>%
      addCircleMarkers(data = site_used, lat = ~ lat, lng = ~ long, layerId = ~stationid, radius=2,  fillOpacity = 0.5,color="black") %>%
      addProviderTiles(providers$CartoDB.Positron)
   

    
    
    
    #generate overview_tables
    
    kabel_raw = calibration.env$rm_model_summary_kable(reference,clean_sites,"ReferenceMetal","PPH","TraceMetal","PPM")
    kabel_normalized = calibration.env$rm_model_summary_kable(reference,clean_sites_normalized,"ReferenceMetal","PPH","TraceMetal","PPM")
    kabel_slope_and_intercept = calibration.env$rm_model_summary_kable(reference,clean_sites_normalized,"ReferenceMetal","PPH","TraceMetal","PPM",slope_test=T)

    output$OverviewTableNormal = function(){kabel_normalized}
    output$OverviewTableRaw = function(){kabel_raw}
    output$SlopeInterceptTest = function(){kabel_slope_and_intercept}
    output$SedimentSummaryStatistics = function(){
      calibration.env$weightedSedimentSummaryStatistics%>%
        filter(analyte %in% c(reference,calibration.env$trace_metals))%>%
        arrange(factor(analyte,levels=c(reference,calibration.env$trace_metals)))%>%
        kable(format ="html",booktabs = T,escape=F,align="c") %>%
        kable_styling(position = "center") %>%
        column_spec(1:8, width = "5cm")
      
        }
     
  })

  
  # Trace Metal Overview Pageset
  observeEvent(input$tm_button,{
    showTab(inputId="tabs",target="Table")
    showTab(inputId="tabs",target="Reference Element Comparison")
    hideTab(inputId="tabs",target="Overview Table")
    showTab(inputId="tabs",target="Baseline Calibration")
    showTab(inputId="tabs",target="Calibration Curve")
    calibration_sites = input$debug_mode
    
    tryCatch({calibration_curve = calibration.env$calibration_plot(input$reference_metal,input$trace_metal,clean_sites_normalized,dirty_sites,calibration_sites)},
             error = function(e){
               calibration_curve <<- calibration.env$calibration_plot(input$reference_metal,input$trace_metal,clean_sites,dirty_sites,calibration_sites)
               calibration_curve[["pointsPlot"]]<<- calibration_curve[["pointsPlot"]]+labs(caption="NOTE: Could not normalize the baseline relationship. Prediction intervals may be skewed")
               
             })

    output$calibrationPlot = renderPlot({
      
      plot(calibration_curve[["pointsPlot"]])})
    
    output$residualsPlot = renderPlot({
      
      plot(calibration_curve[["residualsPlot"]])})
    
    
    output$residualsByLat = renderPlot({
      
      plot(calibration_curve[["residualsByLat"]])})
    
    output$residualsByDepth = renderPlot({
      
      plot(calibration_curve[["residualsByDepth"]])})
    
    
    output$residualsByLong = renderPlot({
      
      plot(calibration_curve[["residualsByLong"]])})
    
    output$APByLat = renderPlot({plot(calibration_curve[["APByLat"]])})
    output$APByLong = renderPlot({plot(calibration_curve[["APByLong"]])})
    
    output$StratumPlot = renderPlot({plot(calibration_curve[["StratumPlot"]])})
    
    
    reference=input$reference_metal
    
    if(input$debug_mode){
      site_used = clean_sites
    } else {
      site_used = dirty_sites
    }
    # print out the summary tables
    
    output$TraceModelSummary = renderPrint({calibration_curve[["model"]]})
    
    output$TraceMetalPredictions = function(){
      predict_vals = predict(calibration_curve[["model"]],newdata = calibration_curve[["dirty_sites"]])
      df = as.data.frame(calibration_curve[["dirty_sites"]]$PPM)
      colnames(df) = c(input$trace_metal)
      df[["Predicted Amount"]] = predict_vals
      df[["Station"]] = calibration_curve[["dirty_sites"]]$stationid
      
      df[["Stratum"]] = calibration_curve[["dirty_sites"]]$Stratum
      df = df[,c("Station","Stratum",input$trace_metal,"Predicted Amount")]
      kabel = kable(df, format ="html",booktabs = T,escape=F,align="c") %>%
             kable_styling(position = "center")
      return(kabel)
    }
    normalizer_kable = calibration.env$normalizer_summary_kable(clean_sites_normalized,"ReferenceMetal","PPH","TraceMetal","PPM")
    output$"NormalizerComparison" = function(){normalizer_kable}
    
    # pal <- colorNumeric(
    #   palette = c("green"),
    #   na.color = "red",
    #   domain = c(1))
    # 
    
    pal = function(data){
      data[data==TRUE] = "green"
      data[data==FALSE] = "red"
      
      data
    }
    proxy <- leafletProxy("mymap")


    proxy %>% setView(lng = -118.16, lat = 33.75, zoom = 7)  %>% #setting the view over ~ center of bight
      clearMarkers() %>% 
    addCircleMarkers(data = calibration_curve[["predicted_PPM"]], 
                     lat = ~ lat, 
                     lng = ~ long, 
                     radius=5, 
                     popup=~paste("<table>",
                                  "<tr><th>Station: </th><th>",stationid,"</th></tr>",
                                  "<tr><td>PPM: </td><td>",PPM,"</td></tr>",
                                  "<tr><td>Stratum: </td><td>",Stratum,"</td></tr>",
                                  "<tr><td>Latitude: </td><td>",lat,"</td></tr>",
                                  "<tr><td>Longitude: </td><td>",long,"</td></tr>",
                                  "<tr><td>Depth: </td><td>",depth,"</td></tr>",
                                  "</table>"),
                     label=~stationid,
                     layerId = ~stationid,
                     fillOpacity = 0.5,
                     color=~pal(Interval)) %>%
      addProviderTiles(providers$CartoDB.Positron)
    
  })
  
  
  
  
    
  
  
    
  # select trace metal and contaminant, spit out table with:
  # mse, residual, model summary, map of anthropogenic effect
  # table from the paper (slope, intercept), table 3
  
  
  
  
}
