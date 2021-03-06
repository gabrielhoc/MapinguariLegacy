#' Transform environmental rasters in ecophysiological rasters.
#'
#' \code{transform_rasters} Get model predictions for a raster stack
#'
#' @param raster_stack RasterStack. Stack with environmental layers.
#' @param FUN_qlist list. A list of unevaluated expressions, as created by function qlist.
#' @param separator character. Character that separates variable names, years and scenarios.
#' @param alert integer. Plays a sound alert when function is done running. See documentation of package \code{beepr} for description of sound options.
#'
#' @return Returns a RasterStack with layers for the predictions required.
#'
#' @examples
#'
#' FulanusEcoRasters_present <-
#'   get_rasters(
#'     raster_source = "/Users/gabriel/Documents/Mapinguari/global_grids_10_minutes",
#'     ext = FulanusDistribution,
#'     margin = 5,
#'     non_fixed_var = c('prec', 'tmin', 'tmax'),
#'     fixed_var = 'alt',
#'     years = c("present"),
#'     reorder = TRUE)
#'
#' transform_rasters(raster_stack = FulanusEcoRasters_present$present,
#'   FUN = qlist(total_1sem = sum(tmax[[1:6]]),
#'     mean_1sem = mean(tmax[[1:6]]),
#'     sd_1sem = sd(tmax[[1:6]]),
#'     total_2sem = sum(tmax[[7:12]]),
#'     mean_2sem = mean(tmax[[7:12]]),
#'     sd_2sem = sd(tmax[[7:12]])),
#'   separator = '_',
#'   alert = NULL)
#'
#' @export

transform_rasters <- function(raster_stack,
  FUN_qlist,
  separator = '_',
  alert = NULL){

  split_vars <-
    raster_stack %>%
    names() %>%
    stringr::str_split(separator) %>%
    lapply(`[`, 1)

  unique_split_vars <- unique(split_vars)

  separate_list <-
    lapply(unique_split_vars, function(y){

      which(split_vars == y) %>%
        raster_stack[[.]] %>%
        raster::stack()
    }
    )

  names(separate_list) <- unique_split_vars

  for (i in 1:length(separate_list)) assign(names(separate_list)[i], separate_list[[i]])

  output <-
    lapply(FUN_qlist, function(ww){

      FUN_list <- as.list(ww)

      actualFUN <- eval(FUN_list[[1]])

      arguments <- if (inherits(FUN_list[-1], "list")) {
        lapply(FUN_list[-1], eval, parent.frame(n = 2))
        } else {
        lapply(list(FUN_list[-1]), eval, parent.frame(n = 2))
  }

      isRaster <- lapply(arguments, function(y) class(eval(y)) == 'RasterStack' | class(eval(y)) == 'RasterLayer' | class(eval(y)) == 'RasterBrick') %>% unlist()

      raster_args <- lapply(arguments[isRaster], eval)
      args_stack <- raster::stack(raster_args)
      other_args <-  lapply(arguments[!isRaster], eval)

      raster_lengths <- unlist(lapply(raster_args, raster::nlayers))

      durations <- lapply(raster_lengths, function(z) 1:z)
      start_ind <- lapply(1:length(raster_lengths), function(i) sum(raster_lengths[1:i][-i]))

      index_list <- lapply(1:length(raster_lengths), function(i) start_ind[[i]] + durations[[i]])

      adaptedFUN <- function(yy, args, .FUN){

          call_list_rasters <-
            lapply(index_list, function(z) yy[z])

          names(call_list_rasters) <- names(raster_args)

          call_list <- append(call_list_rasters, args)

          do.call(what = .FUN, args = call_list)

      }

      formals(adaptedFUN)$args <- other_args
      formals(adaptedFUN)$.FUN <- actualFUN

      ncores <- parallel::detectCores() - 1
      raster::beginCluster(ncores, type = 'SOCK')

      transformed_rasters <- try(raster::clusterR(x = args_stack, fun = raster::overlay,  args = list(fun = adaptedFUN)), silent = TRUE)

      if (class(transformed_rasters) == 'try-error') print("trying not parallelized version")

      if (class(transformed_rasters) == 'try-error') transformed_rasters <- raster::overlay(args_stack, fun = adaptedFUN)

      raster::endCluster()

      names(transformed_rasters) <- ifelse(names(transformed_rasters) == 'layer', paste(paste(ww), collapse = separator), names(transformed_rasters))

      transformed_rasters

    })

  for (i in 1:length(output)) { names(output[[i]]) <-  paste(names(FUN_qlist)[[i]], 1:raster::nlayers(output[[i]]), sep = separator) }

  if (!is.null(alert)) {beepr::beep(alert)}

  return(raster::stack(output))

}
