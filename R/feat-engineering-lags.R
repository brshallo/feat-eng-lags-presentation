## Code to turn-off warnings
defaultW <- getOption("warn")
options(warn = -1)
# run at end to turn warnings back on
options(warn = defaultW)

## ----load-in-packages------------------------------------------------------------------------
library(tidyverse)
library(lubridate)
library(tidymodels)

## --------------------------------------------------------------------------------------------
# inspections_restaurants <- read_csv(here::here("data", "inspections-restaurants.csv"))
inspections_restaurants <- read_csv("https://raw.githubusercontent.com/brshallo/feat-eng-lags-presentation/main/data/inspections-restaurants.csv")


## ----time-based-features---------------------------------------------------------------------
data_time_feats <- inspections_restaurants %>% 
  arrange(date) %>% 
  mutate(SCORE_yr_overall = slider::slide_index_dbl(SCORE, 
                                                    .i = date, 
                                                    .f = mean, 
                                                    na.rm = TRUE, 
                                                    .before = lubridate::days(365), 
                                                    .after = -lubridate::days(1))
         ) %>% 
  group_by(HSISID) %>% 
  mutate(SCORE_lag = lag(SCORE),
         SCORE_recent = slider::slide_index_dbl(SCORE, 
                                                date, 
                                                mean, 
                                                na.rm = TRUE, 
                                                .before = lubridate::days(365*3), 
                                                .after = -lubridate::days(1), 
                                                .complete = FALSE),
         days_since_open = (date - RESTAURANTOPENDATE) / ddays(1),
         days_since_last = (date - lag(date)) / ddays(1)) %>% 
  ungroup() %>% 
  arrange(date)


## ----filter-data-----------------------------------------------------------------------------
data_time_feats <- data_time_feats %>% 
  filter(date >= (max(date) - years(7)), !is.na(SCORE_lag))


## ----initial-split---------------------------------------------------------------------------
initial_split <- rsample::initial_time_split(data_time_feats, prop = .8)
train <- rsample::training(initial_split)
test <- rsample::testing(initial_split)


## ----resampling-splits-----------------------------------------------------------------------
resamples <- rsample::sliding_period(train, 
                                     index = date, 
                                     period = "month", 
                                     lookback = 36, 
                                     assess_stop = 3, 
                                     step = 3)


## ----check-resampling-splits-----------------------------------------------------------------
devtools::source_gist("https://gist.github.com/brshallo/7d180bde932628a151a4d935ffa586a5")

resamples  %>% 
  extract_dates_rset() %>% 
  print() %>% 
  plot_dates_rset() 


## ----make-recipes----------------------------------------------------------------------------
rec_general <- recipes::recipe(SCORE ~ ., data = train) %>% 
  step_rm(RESTAURANTOPENDATE) %>% 
  update_role(HSISID, new_role = "ID") %>% 
  step_other(INSPECTOR, TYPE, threshold = 50) %>% 
  step_string2factor(one_of("TYPE", "INSPECTOR")) %>%
  step_novel(one_of("TYPE", "INSPECTOR")) %>%
  # note that log transformations are completely superfluous for the random
  # forest model fit (is only valuable for the linear mod)
  step_log(days_since_open, days_since_last) %>% 
  step_date(date, features = c("dow", "month")) %>% 
  update_role(date, new_role = "ID") %>% 
  step_zv(all_predictors()) 


## ----peak-prepped-recipe---------------------------------------------------------------------
prep(rec_general, data = train) %>% 
  juice() %>% 
  glimpse() 


## ----specify-linear-model--------------------------------------------------------------------
lm_mod <- parsnip::linear_reg() %>% 
  set_engine("lm") %>% 
  set_mode("regression")

lm_workflow_rs <- workflows::workflow() %>% 
  add_model(lm_mod) %>% 
  add_recipe(rec_general) %>% 
  fit_resamples(resamples,
                control = control_resamples(save_pred = TRUE))


## ----specify-rf-model------------------------------------------------------------------------
rand_mod <- parsnip::rand_forest() %>% 
  set_engine("ranger") %>% 
  set_mode("regression")
  
set.seed(1234)
rf_workflow_rs <- workflow() %>% 
  add_model(rand_mod) %>% 
  add_recipe(rec_general) %>% 
  fit_resamples(resamples,
                control = control_resamples(save_pred = TRUE))


## ----specify-null-model----------------------------------------------------------------------
null_mod <- parsnip::null_model(mode = "regression") %>% 
  set_engine("parsnip")

null_workflow_rs <- workflow() %>% 
  add_model(null_mod) %>% 
  add_formula(SCORE ~ NULL) %>%
  fit_resamples(resamples,
                control = control_resamples(save_pred = TRUE))


## ----collect-overall-performance-------------------------------------------------------------
mod_types <- list("lm", "rf", "null")

avg_perf <- map(list(lm_workflow_rs, rf_workflow_rs, null_workflow_rs), 
                collect_metrics) %>% 
  map2(mod_types, ~mutate(.x, source = .y)) %>% 
  bind_rows() 


## ----extract-performance-each-split----------------------------------------------------------
extract_splits_metrics <- function(rs_obj, name){
  
  rs_obj %>% 
    select(id, .metrics) %>% 
    unnest(.metrics) %>% 
    mutate(source = name)
}

splits_perf <-
  map2(
    list(lm_workflow_rs, rf_workflow_rs, null_workflow_rs),
    mod_types,
    extract_splits_metrics
  ) %>%
  bind_rows()


## ----plot-performance------------------------------------------------------------------------
splits_perf %>% 
  mutate(id = forcats::fct_rev(id)) %>% 
  ggplot(aes(x = .estimate, y = id, colour = source))+
  geom_vline(aes(xintercept = mean, colour = fct_relevel(source, c("lm", "rf", "null"))), 
           alpha = 0.4,
           data = avg_perf)+
  geom_point()+
  facet_wrap(~.metric, scales = "free_x")+
  xlim(c(0, NA))+
  theme_bw()+
  labs(caption = "Vertical lines are average performance as captured by `tune::collect_metrics()`")


## ----t-test-mod-performance------------------------------------------------------------------
t.test(
  filter(splits_perf, source == "lm", .metric == "rmse") %>% pull(.estimate),
  filter(splits_perf, source == "rf", .metric == "rmse") %>% pull(.estimate),
  paired = TRUE
) %>% 
  broom::tidy() %>% 
  mutate(across(where(is.numeric), round, 4)) %>% 
  knitr::kable() 


## ---- eval = FALSE---------------------------------------------------------------------------
## rec_glmnet <- rec_general %>%
##   step_dummy(all_predictors(), -all_numeric()) %>%
##   step_normalize(all_predictors(), -all_nominal()) %>%
##   step_zv(all_predictors())
## 
## glmnet_mod <- parsnip::linear_reg(penalty = tune(), mixture = tune()) %>%
##   set_engine("glmnet") %>%
##   set_mode("regression")
## 
## glmnet_workflow <- workflow::workflow() %>%
##   add_model(glmnet_mod) %>%
##   add_recipe(rec_glmnet)
## 
## glmnet_grid <- tidyr::crossing(penalty = 10^seq(-6, -1, length.out = 20), mixture = c(0.05,
##     0.2, 0.4, 0.6, 0.8, 1))
## 
## glmnet_tune <- tune::tune_grid(glmnet_workflow,
##                          resamples = resamples,
##                          control = control_grid(save_pred = TRUE),
##                          grid = glmnet_grid)


## ---- eval = FALSE---------------------------------------------------------------------------
## rand_mod <- parsnip::rand_forest(mtry = tune(), min_n = tune(), trees = 1000) %>%
##   set_engine("ranger") %>%
##   set_mode("regression")
## 
## rf_workflow <- workflow() %>%
##   add_model(rand_mod) %>%
##   add_recipe(rec_general)
## 
## cores <- parallel::detectCores()
## 
## set.seed(1234)
## rf_tune <- tune_grid(rf_workflow,
##                          resamples = resamples,
##                          control = control_grid(save_pred = TRUE),
##                          grid = 25)

