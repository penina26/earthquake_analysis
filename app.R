library(shiny)
library(leaflet)
library(ggplot2)
library(xts)
library(lubridate)
library(dplyr)
library(tidyverse)
library(ggthemes)
library(DT)
library(ggrepel)
library(plotly)

# Load data and handle potential issues
df <- read.csv("Significant_Earthquakes-1965-2016.csv")

# filter data related to earthquakes

df <- df %>% filter(Type == "Earthquake")
df$Date <- as.Date(df$Date, format = "%m/%d/%Y")
df$Year <- year(df$Date)
df <- df[!is.na(df$Year), ]


#create a Shiny UI
ui <- fluidPage(
  titlePanel("Earthquake Analysis 1965-2016"),
    
  sidebarLayout(
    sidebarPanel(
      sliderInput("yearRange", "Select Year Range:", 
                  min = as.numeric(gsub("\\,", "",min(df$Year))), 
                  max = as.numeric(gsub("\\,", "",max(df$Year))), 
                  value = c(as.numeric(gsub("\\,", "",min(df$Year))), as.numeric(gsub("\\,", "",max(df$Year)))),
                  step = 1), 
      
    
    sliderInput("magnitude_range", "Magnitude Range",
                min(df$Magnitude), 
                max(df$Magnitude), 
                value = c(min(df$Magnitude), max(df$Magnitude)),
                step = 0.1)
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Map",
                 leafletOutput("map")
        ),
        tabPanel("Magnitude Distribution",
                 plotOutput("magnitude_distribution")
        ),
        tabPanel("Depth Distribution",
                 plotOutput("depth_distribution")
        ),
        tabPanel("Magnitude vs Depth",
                 plotOutput("magnitude_vs_depth")
        ),
        tabPanel("Magnitude Yearly Trend",
                 plotlyOutput("magnitude_over_time")
        ),
        tabPanel("Yearly Earthquake Frequency",
                 plotlyOutput("number_of_earthquakes")
        ),
        tabPanel("The Dataset",
                 DTOutput("mydatatable")
        )
      )
    )
  )
  
)


#server logic

server <- function(input, output){
  #reactive functions for filtered data and visualizations
  filtered_df <- reactive({
    filter(df, 
           Magnitude >= input$magnitude_range[1] & 
           Magnitude <= input$magnitude_range[2] & 
           Year >= input$yearRange[1] & 
           Year <= input$yearRange[2])
  })
  
  #the map

  output$map <- renderLeaflet({
    pal <- colorNumeric("viridis", domain = filtered_df()$Magnitude)
    
    leaflet(filtered_df()) %>%
      addTiles() %>%
      addCircleMarkers(lng = ~Longitude, lat = ~Latitude,
                       radius = 3, stroke = FALSE, fillOpacity = 0.5,
                       color = ~pal(Magnitude),
                       label = ~paste("Magnitude:", Magnitude)) %>%
      addControl(paste(title = "Global Earthquake Map"), position = "topright") %>% 
      leaflet::addLegend(pal = pal, values = filtered_df()$Magnitude, title = "Magnitude", position = "bottomright") %>%
      setView(lng = 17, lat = 0, zoom = 1)
  })
  #distribution of the magnitude
  output$magnitude_distribution <- renderPlot({
    pl <- ggplot(filtered_df(), aes(x = Magnitude)) +
      geom_histogram(color="black", aes(fill = ..count..), bins = 40) +
      ggtitle("Distribution of Earthquake Magnitude from 1965-2016")
    print(pl)
  })
  #distribution of the earthquake depth
  output$depth_distribution <- renderPlot({
    pl <- ggplot(filtered_df(), aes(x = Depth)) +
      geom_histogram(color="black",  aes(fill = ..count..), bins = 40) +
      ggtitle("Distribution of Earthquake Depth from 1965-2016")
    print(pl)
  })
  
  #checking correlation-magnitude vs depth
  
  output$magnitude_vs_depth <- renderPlot({
    pl <- ggplot(filtered_df(), aes(x = Depth, y = Magnitude)) +
      geom_point(aes(color = Magnitude)) +  # Assign Magnitude to color aesthetic
      scale_color_viridis_c() +  # viridis color palette
      geom_smooth(method = "lm", se = FALSE) +
      ggtitle("Magnitude vs Depth")
      
    print(pl)
  })
  
  
  #magnitude trend
  
  output$magnitude_over_time <- renderPlotly({
    ts_data <- xts(filtered_df()$Magnitude, order.by = filtered_df()$Date)
    annual_ts <- apply.yearly(ts_data, mean)
    
    pl <- ggplot(annual_ts, aes(x = as.POSIXct(Index), y = annual_ts)) +
      geom_line(color = "#00008B") +
      scale_x_datetime(date_breaks = "1 year", date_labels = "%Y") +
      ggtitle("Earthquake Magnitude over Time (Annual)") +
      theme(plot.margin = margin(20, 20, 20, 20),
            axis.text.x = element_text(angle = 90),
            panel.grid.major = element_line(color = "white", size = 0.5),
            panel.grid.minor = element_line(color = "white", size = 0.25)) +
      labs(x = "Year", y = "Magnitude")
    
    ggplotly(pl)
  })

  #number of eathquakes(yearly)
  output$number_of_earthquakes <- renderPlotly({
    yearly_counts <- filtered_df() %>%
      count(Year)
    
    pl <- ggplot(yearly_counts, aes(x = Year, y = n)) +
      geom_line(color = "#00008B") +
      scale_x_continuous(breaks = yearly_counts$Year) +
      ggtitle("Number of Earthquakes by Year") +
      theme(plot.margin = margin(20, 20, 20, 20),
            axis.text.x = element_text(angle = 90, hjust = 1),
            panel.grid.major = element_line(color = "white", size = 0.5),
            panel.grid.minor = element_line(color = "white", size = 0.25)) +
      labs(x = "Year", y = "Number of Earthquakes")
    
    ggplotly(pl)
  })
  
  #the data table

  output$mydatatable <- renderDT({

    datatable(filtered_df(), options = list(pageLength = 5, scrollX = TRUE), rownames = FALSE)
  })
  
}

#run the app
shinyApp(ui, server)