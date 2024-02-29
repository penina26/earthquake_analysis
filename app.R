library(shiny)
library(leaflet)
library(ggplot2)
library(xts)
library(lubridate)
library(dplyr)
library(tidyverse)
library(DT)
library(plotly)

# Load data and handle potential issues
df <- read.csv("Significant_Earthquakes-1965-2016.csv")

# filter data related to earthquakes
df <- df %>% filter(Type == "Earthquake")
df$Date <- as.Date(df$Date, format = "%m/%d/%Y")
df$Year <- year(df$Date)
df <- df[!is.na(df$Year), ]

# Create magnitude ranges
df$MagnitudeRange <- cut(df$Magnitude, breaks = seq(5, 10, by = 1), include.lowest = TRUE)

# UI definition
ui <- fluidPage(

  titlePanel("Earthquake Analysis 1965-2016"),
  sidebarLayout(
    sidebarPanel(
      sliderInput("yearRange", "Select Year Range:", 
                  min = min(df$Year), 
                  max = max(df$Year), 
                  value = c(min(df$Year), max(df$Year)),
                  step = 1),
      sliderInput("magnitude_range", "Magnitude Range",
                  min(df$Magnitude), 
                  max(df$Magnitude), 
                  value = c(min(df$Magnitude), max(df$Magnitude)),
                  step = 0.1)
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Yearly Earthquake Frequency",
                 plotlyOutput("number_of_earthquakes")),
        
        tabPanel("Average Magnitude Trend",
                 plotlyOutput("magnitude_over_time")),
        
        tabPanel("Annual earthquake occurrence by magnitude",
                 plotOutput("barstack")),
        
        tabPanel("Magnitude Distribution",
                 plotOutput("magnitude_distribution")),
        
        tabPanel("Depth Distribution",
                 plotOutput("depth_distribution")),
        
        tabPanel("Continental Burden of Earthquake Magnitudes",
                 plotOutput("bubblechart")),
        
        tabPanel("Detailed Continental Burden of Earthquake Magnitudes",
                 leafletOutput("map")),
        
        tabPanel("Correlation Analysis",
                 plotOutput("magnitude_vs_depth")), 
        
        tabPanel("The Raw Dataset",
                 DTOutput("mydatatable"))
      )
    )
  )
)

# Server logic
server <- function(input, output){
  
  # Reactive function for filtered data
  filtered_df <- reactive({
    filter(df, 
           Magnitude >= input$magnitude_range[1] & 
             Magnitude <= input$magnitude_range[2] & 
             Year >= input$yearRange[1] & 
             Year <= input$yearRange[2])
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
  
  #magnitude trend
  
  output$magnitude_over_time <- renderPlotly({
    ts_data <- xts(filtered_df()$Magnitude, order.by = filtered_df()$Date)
    annual_ts <- apply.yearly(ts_data, mean)
    
    pl <- ggplot(annual_ts, aes(x = as.POSIXct(Index), y = annual_ts)) +
      geom_line(color = "#00008B") +
      scale_x_datetime(date_breaks = "1 year", date_labels = "%Y") +
      ggtitle("Earthquake Magnitude over Time") +
      theme(plot.margin = margin(20, 20, 20, 20),
            axis.text.x = element_text(angle = 90),
            panel.grid.major = element_line(color = "white", size = 0.5),
            panel.grid.minor = element_line(color = "white", size = 0.25)) +
      labs(x = "Year", y = "Magnitude")
    
    ggplotly(pl)
  })
  
  # stacked barchart (magnitude)
  
  output$barstack <- renderPlot({
    # Count by year and magnitude range
    yearly_magnitude_counts <- filtered_df() %>%
      group_by(Year, MagnitudeRange) %>%
      summarise(Count = n())
    
    # Plot stacked bar chart
    pl <- ggplot(yearly_magnitude_counts, aes(x = Year, y = Count, fill = MagnitudeRange)) +
      geom_bar(stat = "identity") +
      labs(title = "Magnitude Range by Year ", x = "Year", y = "Number") 
    pl + scale_fill_viridis_d()
  })

  
  #distribution of the magnitude
  output$magnitude_distribution <- renderPlot({
    pl <- ggplot(filtered_df(), aes(x = Magnitude)) +
      geom_histogram(color="black", aes(fill = ..count..), bins = 40) +
      ggtitle("Magnitude Distribution Patterns")
    pl
  })
  #distribution of the earthquake depth
  output$depth_distribution <- renderPlot({
    pl <- ggplot(filtered_df(), aes(x = Depth)) +
      geom_histogram(color="black",  aes(fill = ..count..), bins = 40) +
      ggtitle("Depth Distribution Patterns")
    pl
  })
  
  #bubble chart
  
  output$bubblechart <- renderPlot({
    
    # Create a world map
    world_map <- map_data("world")
    
    # Map Visualization with Earthquake Locations
    
    pl <- ggplot() +
      geom_polygon(data = world_map, aes(x = long, y = lat, group = group), fill = "white", color = "black") +
      geom_point(data = filtered_df(), aes(x = Longitude, y = Latitude, color = Magnitude, size = Magnitude), alpha = 0.5) +
      scale_color_gradient(low = "blue", high = "red")+
      labs(title = "Earthquake Magnitude by Location", x = "Longitude", y = "Latitude") +
      theme_minimal()
    
    pl
    
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
  
  #checking correlation-magnitude vs depth
  
  output$magnitude_vs_depth <- renderPlot({
    pl <- ggplot(filtered_df(), aes(x = Depth, y = Magnitude)) +
      geom_point(aes(color = Magnitude)) +  # Assign Magnitude to color aesthetic
      scale_color_viridis_c() +  # viridis color palette
      geom_smooth(method = "lm", se = FALSE) +
      ggtitle("Magnitude by Depth")
    
    pl
  })
  
  # The data table
  output$mydatatable <- renderDT({
    datatable(filtered_df(), options = list(pageLength = 5, scrollX = TRUE), rownames = FALSE)
  })
}

# Run the app
shinyApp(ui, server)

  