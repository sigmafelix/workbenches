#' Query STAC from Planetary Computer with parameters
#' @param url_root character(1). https address string
#' @param collections character. Collections.
#' @param asset_names character. IDs.
#' @param date_range character(1). Date range of the search.
#' Should be formatted YYYY-MM-DD/YYYY-MM-DD. The former should
#' predate the latter.
#' @param bbox numeric(4). [sf::st_bbox] output.
#' @param token character(1). Planetary Computer access token.
#' @param return_query logical(1). Return RSTACQuery object for gdalcube run.
#' @returns vsicurl data path when `return_query = TRUE`
#' or RSTACQuery object when `return_query = FALSE`.
#' @author Insang Song
#' @references [STAC specification][https://www.stacspec.org]
#' @importFrom rstac stac_search
#' @importFrom rstac get_request
#' @importFrom rstac stac
#' @importFrom rstac assets_url
#' @importFrom rstac items_sign
#' @importFrom rstac sign_planetary_computer
#' @export
query_stac_pcomp <-
  function(
    url_root = "https://planetarycomputer.microsoft.com/api/stac/v1",
    collections = NULL,
    asset_names = NULL,
    date_range = NULL,
    bbox = NULL,
    token = NULL,
    return_query = FALSE
  ) {

    # get full path to the dataset and extents
    full_query <-
      rstac::stac(url_root) |>
      rstac::stac_search(
        collections = collections,
        bbox = bbox,
        datetime = date_range
      ) |>
      rstac::get_request()
    if (return_query) {
      return(full_query)
    } 
    url_query <- full_query |>
      rstac::items_sign(
        sign_fn =
        rstac::sign_planetary_computer(
          headers = c("Ocp-Apim-Subscription-Key" = token)
        )
      ) |>
      rstac::assets_url(asset_names = asset_names)
    return(url_query)
    # vsicurl base
    # vsi_template <-
    #   paste0(
    #     "/vsicurl",
    #     "?pc_url_signing=yes",
    #     "&pc_collection=%s",
    #     "&url=%s"
    #   )

    # vsi_full <-
    #   sprintf(
    #     vsi_template,
    #     collections,
    #     full_query
    #   )
    # return(vsi_full)
  }
