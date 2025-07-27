# exactextractr Performance Experiment
# Testing different parameter settings for exact_extract()
# by Claude
# Prompt:
# Write an experiment code for R exactextractr::exact_extract()
# with different parameter settings:
# 1) use fun="frac"
# 2) try three buffer sizes, 100, 1000, and 5000 meters.
# 3) try different max_cells_in_memory values: 3e6, 3e7(default), and 1e8
# 4) try different input partitioning approaches: use sizable (>10000 rows) polygon sf object and
#    use it as-is; and split it into chunks with 10 and 100 rows (i.e., 1000 and 100 rows)
#    to process it.
# Summarize the total elapsed time and memory usage.
# Don't repeat each experiment more than 10 times.


library(exactextractr)
library(sf)
library(terra)
library(dplyr)
library(microbenchmark)
library(pryr)
library(ggplot2)

# Set up experiment parameters
set.seed(42)

# Create synthetic test data
create_test_data <- function() {
  # Create a large raster (adjust size based on your system capabilities)
  raster_extent <- ext(c(0, 1000, 0, 1000))
  raster_res <- 10  # 10m resolution = 100x100 = 10,000 cells
  
  # Create raster with some pattern
  r <- rast(raster_extent, res = raster_res)
  values(r) <- runif(ncell(r), 0, 100)
  
  # Create polygon dataset with >10,000 features
  n_polygons <- 12000
  
  # Generate random polygon centers
  centers_x <- runif(n_polygons, 50, 950)
  centers_y <- runif(n_polygons, 50, 950)
  
  # Create polygons with varying sizes
  polygons <- list()
  for (i in 1:n_polygons) {
    # Create rectangular polygons with random sizes
    size <- runif(1, 5, 25)
    poly_coords <- matrix(c(
      centers_x[i] - size, centers_y[i] - size,
      centers_x[i] + size, centers_y[i] - size,
      centers_x[i] + size, centers_y[i] + size,
      centers_x[i] - size, centers_y[i] + size,
      centers_x[i] - size, centers_y[i] - size
    ), ncol = 2, byrow = TRUE)
    
    polygons[[i]] <- st_polygon(list(poly_coords))
  }
  
  # Create sf object
  polys_sf <- st_sf(
    id = 1:n_polygons,
    area_class = sample(c("small", "medium", "large"), n_polygons, replace = TRUE),
    geometry = st_sfc(polygons, crs = st_crs(r))
  )
  
  return(list(raster = r, polygons = polys_sf))
}

# Function to create buffered polygons
create_buffered_polygons <- function(polys, buffer_size) {
  if (buffer_size > 0) {
    return(st_buffer(polys, dist = buffer_size))
  } else {
    return(polys)
  }
}

# Function to split polygons into chunks
split_polygons <- function(polys, n_chunks) {
  n_rows <- nrow(polys)
  chunk_size <- ceiling(n_rows / n_chunks)
  
  chunks <- list()
  for (i in 1:n_chunks) {
    start_idx <- (i - 1) * chunk_size + 1
    end_idx <- min(i * chunk_size, n_rows)
    
    if (start_idx <= n_rows) {
      chunks[[i]] <- polys[start_idx:end_idx, ]
    }
  }
  
  return(chunks[!sapply(chunks, is.null)])
}

# Function to run experiment and measure performance
run_experiment <- function(raster, polygons, buffer_size, max_cells, partition_approach, run_id) {
  
  cat(sprintf("Running: Buffer=%d, MaxCells=%s, Partition=%s, Run=%d\n", 
              buffer_size, format(max_cells, scientific = TRUE), partition_approach, run_id))
  
  # Create buffered polygons
  buffered_polys <- create_buffered_polygons(polygons, buffer_size)
  
  # Apply partitioning approach
  if (partition_approach == "as_is") {
    poly_chunks <- list(buffered_polys)
    chunk_info <- "12000_rows"
  } else if (partition_approach == "10_pieces") {
    poly_chunks <- split_polygons(buffered_polys, 10)
    chunk_info <- sprintf("%d_chunks_avg_%d_rows", length(poly_chunks), 
                         mean(sapply(poly_chunks, nrow)))
  } else if (partition_approach == "100_pieces") {
    poly_chunks <- split_polygons(buffered_polys, 100)
    chunk_info <- sprintf("%d_chunks_avg_%d_rows", length(poly_chunks), 
                         mean(sapply(poly_chunks, nrow)))
  }
  
  # Measure memory before
  mem_before <- as.numeric(mem_used())
  
  # Run exact_extract with timing
  start_time <- Sys.time()
  
  tryCatch({
    results <- list()
    for (i in seq_along(poly_chunks)) {
      chunk_result <- exact_extract(
        raster, 
        poly_chunks[[i]], 
        fun = "frac",
        max_cells_in_memory = max_cells,
        progress = FALSE
      )
      results[[i]] <- chunk_result
    }
    
    # Combine results if multiple chunks
    if (length(results) > 1) {
      final_result <- do.call(rbind, results)
    } else {
      final_result <- results[[1]]
    }
    
    end_time <- Sys.time()
    elapsed_time <- as.numeric(difftime(end_time, start_time, units = "secs"))
    
    # Measure memory after
    mem_after <- as.numeric(mem_used())
    mem_diff <- mem_after - mem_before
    
    # Force garbage collection
    gc()
    mem_final <- as.numeric(mem_used())
    
    return(data.frame(
      buffer_size = buffer_size,
      max_cells = max_cells,
      partition_approach = partition_approach,
      chunk_info = chunk_info,
      run_id = run_id,
      elapsed_time = elapsed_time,
      mem_before = mem_before,
      mem_after = mem_after,
      mem_diff = mem_diff,
      mem_final = mem_final,
      n_results = ifelse(is.data.frame(final_result), nrow(final_result), length(final_result)),
      success = TRUE,
      error_msg = NA
    ))
    
  }, error = function(e) {
    return(data.frame(
      buffer_size = buffer_size,
      max_cells = max_cells,
      partition_approach = partition_approach,
      chunk_info = chunk_info,
      run_id = run_id,
      elapsed_time = NA,
      mem_before = mem_before,
      mem_after = NA,
      mem_diff = NA,
      mem_final = as.numeric(mem_used()),
      n_results = NA,
      success = FALSE,
      error_msg = as.character(e)
    ))
  })
}

# Main experiment function
run_full_experiment <- function() {
  cat("Creating test data...\n")
  test_data <- create_test_data()
  raster <- test_data$raster
  polygons <- test_data$polygons
  
  cat(sprintf("Created raster: %d x %d cells\n", nrow(raster), ncol(raster)))
  cat(sprintf("Created polygons: %d features\n", nrow(polygons)))
  
  # Experiment parameters
  buffer_sizes <- c(0, 100, 1000, 5000)  # Including 0 for no buffer
  max_cells_values <- c(3e6, 3e7, 1e8)
  partition_approaches <- c("as_is", "10_pieces", "100_pieces")
  n_runs <- 3  # Reduced to 3 runs for manageable execution time
  
  # Create experiment grid
  experiment_grid <- expand.grid(
    buffer_size = buffer_sizes,
    max_cells = max_cells_values,
    partition_approach = partition_approaches,
    run_id = 1:n_runs,
    stringsAsFactors = FALSE
  )
  
  cat(sprintf("Total experiments to run: %d\n", nrow(experiment_grid)))
  
  # Run experiments
  results <- list()
  
  for (i in 1:nrow(experiment_grid)) {
    result <- run_experiment(
      raster = raster,
      polygons = polygons,
      buffer_size = experiment_grid$buffer_size[i],
      max_cells = experiment_grid$max_cells[i],
      partition_approach = experiment_grid$partition_approach[i],
      run_id = experiment_grid$run_id[i]
    )
    
    results[[i]] <- result
    
    # Progress update
    if (i %% 10 == 0) {
      cat(sprintf("Completed %d/%d experiments\n", i, nrow(experiment_grid)))
    }
    
    # Force garbage collection between experiments
    gc()
    Sys.sleep(1)  # Brief pause to let system stabilize
  }
  
  # Combine results
  final_results <- do.call(rbind, results)
  
  return(final_results)
}

# Function to summarize results
summarize_results <- function(results) {
  cat("\n=== EXPERIMENT SUMMARY ===\n")
  
  # Overall success rate
  success_rate <- mean(results$success, na.rm = TRUE) * 100
  cat(sprintf("Success rate: %.1f%%\n", success_rate))
  
  # Filter successful results for analysis
  successful_results <- results[results$success == TRUE, ]
  
  if (nrow(successful_results) > 0) {
    # Summary by parameter combinations (averaging across runs)
    summary_stats <- successful_results %>%
      group_by(buffer_size, max_cells, partition_approach) %>%
      summarise(
        mean_elapsed_time = mean(elapsed_time, na.rm = TRUE),
        sd_elapsed_time = sd(elapsed_time, na.rm = TRUE),
        mean_mem_diff = mean(mem_diff, na.rm = TRUE),
        max_mem_diff = max(mem_diff, na.rm = TRUE),
        n_runs = n(),
        .groups = 'drop'
      ) %>%
      arrange(mean_elapsed_time)
    
    cat("\n=== TOP 10 FASTEST CONFIGURATIONS ===\n")
    print(head(summary_stats, 10))
    
    cat("\n=== MEMORY USAGE ANALYSIS ===\n")
    memory_summary <- summary_stats %>%
      arrange(mean_mem_diff) %>%
      select(buffer_size, max_cells, partition_approach, mean_mem_diff, max_mem_diff)
    
    print(head(memory_summary, 10))
    
    # Parameter effect analysis
    cat("\n=== PARAMETER EFFECTS ===\n")
    
    cat("\nBuffer size effect:\n")
    buffer_effect <- successful_results %>%
      group_by(buffer_size) %>%
      summarise(
        mean_time = mean(elapsed_time, na.rm = TRUE),
        mean_memory = mean(mem_diff, na.rm = TRUE),
        .groups = 'drop'
      )
    print(buffer_effect)
    
    cat("\nMax cells effect:\n")
    cells_effect <- successful_results %>%
      group_by(max_cells) %>%
      summarise(
        mean_time = mean(elapsed_time, na.rm = TRUE),
        mean_memory = mean(mem_diff, na.rm = TRUE),
        .groups = 'drop'
      )
    print(cells_effect)
    
    cat("\nPartitioning effect:\n")
    partition_effect <- successful_results %>%
      group_by(partition_approach) %>%
      summarise(
        mean_time = mean(elapsed_time, na.rm = TRUE),
        mean_memory = mean(mem_diff, na.rm = TRUE),
        .groups = 'drop'
      )
    print(partition_effect)
    
  } else {
    cat("No successful experiments to analyze!\n")
  }
  
  # Error summary
  failed_results <- results[results$success == FALSE, ]
  if (nrow(failed_results) > 0) {
    cat("\n=== FAILED EXPERIMENTS ===\n")
    error_summary <- failed_results %>%
      group_by(buffer_size, max_cells, partition_approach) %>%
      summarise(
        n_failures = n(),
        error_msg = first(error_msg),
        .groups = 'drop'
      )
    print(error_summary)
  }
  
  return(list(summary_stats = summary_stats, raw_results = results))
}

# Run the experiment
cat("Starting exactextractr performance experiment...\n")
cat("This may take several minutes to complete.\n\n")

experiment_results <- run_full_experiment()
summary_output <- summarize_results(experiment_results)

# Save results
save(experiment_results, summary_output, file = "exactextractr_experiment_results.RData")

cat("\n=== EXPERIMENT COMPLETE ===\n")
cat("Results saved to: exactextractr_experiment_results.RData\n")
cat("Use load('exactextractr_experiment_results.RData') to reload results\n")