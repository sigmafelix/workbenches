# R-Rust integration
# Last edited 2025-07-31
# TODO: optimization strategies

code <- r"(
#[extendr]
fn jsd_r_simple(p: RMatrix<f64>, q: RMatrix<f64>) -> f64 {
    // Work directly with slices - no copying
    let p_slice = p.as_real_slice().unwrap();
    let q_slice = q.as_real_slice().unwrap();

    let mut kl_pm = 0.0;
    let mut kl_qm = 0.0;

    // Single pass calculation to avoid multiple iterations
    for (pi, qi) in p_slice.iter().zip(q_slice.iter()) {
        let mi = 0.5 * (pi + qi);
        
        if *pi > 0.0 && mi > 0.0 {
            kl_pm += pi * (pi / mi).log2();
        }
        
        if *qi > 0.0 && mi > 0.0 {
            kl_qm += qi * (qi / mi).log2();
        }
    }

    0.5 * (kl_pm + kl_qm)
})"

rust_source(code = code)

jsd_r_simple(matrix(rnorm(10, 10, 2), nrow = 1), matrix(rnorm(10, 15, 3), nrow = 1))

# pure R
jsd_r_simple_r <- function(p, q) {
  if (length(p) != length(q)) {
    stop("Vectors p and q must have the same length.")
  }
  m <- 0.5 * (p + q)
  kl_pm <- sum(ifelse(p > 0 & m > 0, p * log2(p / m), 0))
  kl_qm <- sum(ifelse(q > 0 & m > 0, q * log2(q / m), 0))
  return(0.5 * (kl_pm + kl_qm))
}

set.seed(123)
N <- 10000
microbenchmark::microbenchmark(
  jsd_r_simple(matrix(rnorm(N, 10, 2), nrow = 1), matrix(rnorm(N, 15, 3), nrow = 1)),
  jsd_r_simple_r(matrix(rnorm(N, 10, 2), nrow = 1), matrix(rnorm(N, 15, 3), nrow = 1)),
  times = 100
)

