
download_progress_callback <- function(progress_bar,
                                       total, amount, ratio,
                                       status_code = NULL) {
  if (is.null(status_code)) {
    progress_bar$update(cbytes = amount %||% 0, btotal = total %||% 0)

  } else if (status_code == 304) {
    progress_bar$update(count = 1, cached = 1, bcached = total %||% 0)

  } else if (status_code == 200) {
    progress_bar$update(
      count = (ratio == 1) %||% 0 + 0,
      cbytes = amount %||% 0,
      btotal = total %||% 0
    )

  } else {
    progress_bar$update(failed = 1)
  }
}

read_etag <- function(etag_file) {
  tryCatch(
    suppressWarnings(read_lines(etag_file, n = 1, warn = FALSE)[1]),
    error = function(e) NA
  )
}

#' @importFrom curl parse_headers_list

download_file <- function(url, target, etag_file = NULL,
                          progress_bar = NULL) {
  "!DEBUG downloading `url`"
  url; target; etag_file
  target <- normalizePath(target, mustWork = FALSE)
  tmp_target <- paste0(target, ".tmp")

  pg <- function(total = NULL, amount = NULL, status_code = NULL, ratio = NULL) {
    download_progress_callback(progress_bar, total = total, amount = amount,
                               ratio = ratio, status_code = status_code)
  }

  http_get(url, file = tmp_target,
           on_progress = if (! is.null(progress_bar)) pg else NULL)$
    then(http_stop_for_status)$
    then(function(resp) {
      "!DEBUG downloaded `url`"
      file.rename(tmp_target, target)
      if (!is.null(etag_file)) {
        etag <- parse_headers_list(resp$headers)[["etag"]]
        writeLines(etag, etag_file)
      }
      resp$status_code
    })
}

download_if_newer <- function(url, target, etag_file = NULL) {
  "!DEBUG downloading (if newer) `url`"
  force(url) ; force(target)

  headers <- character()
  if (!is.null(etag_file)) {
    etag_old <- read_etag(etag_file)
    if (file.exists(target) && !is.na(etag_old)) {
      headers <- c(headers, c("If-None-Match" = etag_old))
    }
  }

  target <- normalizePath(target, mustWork = FALSE)
  tmp_target <- paste0(target, ".tmp")
  mkdirp(dirname(tmp_target))

  http_get(url, file = tmp_target, headers = headers)$
    then(http_stop_for_status)$
    then(function(resp) {
      if (resp$status_code == 304) {
        "!DEBUG download not needed, `url` current"
        ## Current, nothing to do
      } else if (resp$status_code == 200) {
        "!DEBUG downloaded `url`"
        mkdirp(dirname(target))
        file.rename(tmp_target, target)
        etag <- parse_headers_list(resp$headers)[["etag"]]
        if (!is.null(etag_file)) {
          mkdirp(dirname(etag_file))
          writeLines(etag, etag_file)
        }
      }

      resp
    })
}

download_try_list <- function(urls, targets, etag_file = NULL,
                              headers = character(), progress_bar = NULL) {
  "!DEBUG trying download list `paste(urls, collapse = ', ')`"
  assert_that(is.character(urls), length(urls) >= 1)

  force(urls) ; force(targets) ; force(etag_file) ; force(headers)

  if (!is.null(etag_file)) {
    etag_old <- read_etag(etag_file)
    if (any(file.exists(targets)) && !is.na(etag_old)) {
      headers <- c(headers, c("If-None-Match" = etag_old))
    }
  }

  target <- normalizePath(targets[1], mustWork = FALSE)
  tmp_target <- paste(target, ".tmp")

  pg <- function(total = NULL, amount = NULL, status_code = NULL, ratio = NULL) {
    download_progress_callback(progress_bar, total = total, amount = amount,
                               ratio = ratio, status_code = status_code)
  }

  status_code <- NULL
  errors <- NULL
  async_detect(
    urls,
    function(x) {
      force(x)
      http_get(x, file = tmp_target, headers = headers,
               on_progress = if (! is.null(progress_bar)) pg else NULL)$
        then(function(resp) {
          http_stop_for_status(resp)
          if (resp$status_code == "304") {
            "!DEBUG download not needed, `x` current"
            ## Current, nothing to do
          } else {
            "!DEBUG downloaded `url`"
            file.rename(tmp_target, targets[1])
            etag <- parse_headers_list(resp$headers)[["etag"]]
            if (!is.null(etag_file)) writeLines(etag, etag_file)
          }
          unlink(tmp_target)
          status_code <<- resp$status_code
          TRUE
        })$
        catch(function(err) {
          "!DEBUG download failed `url`"
          errors <<- c(errors, structure(list(err), names = x))
        })
    },
    .limit = 1
  )$then(function(url) {
    if (is.null(url)) {
      stop(make_error("All URLs failed", "download_try_list_error",
                      error = errors))
    }
    status_code
  })

}

get_async_value <- function(x) {
  if (is_deferred(x)) x$get_value() else x
}
