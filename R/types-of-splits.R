# USed to generate initial figures describing possible types of data splits

library(tidyverse)
library(lubridate)

theme_set(theme_bw())

set.seed(123)
data <- tibble(id = 1:25,
       groups = rep(letters[1:5], each = 5),
       time = today() + days(1:25)) %>% 
  mutate(split = ifelse(sample(1:25, 25) < 20, "train", "test"))

data %>% 
  ggplot(aes(x = time, fill = split))+
  geom_bar()+
  theme_void()

data %>% 
  mutate(split = ifelse(groups == "b", "train", "test") %>% fct_relevel(c("train", "test"))) %>% 
  ggplot(aes(x = time, fill = split))+
  geom_bar()+
  geom_point(aes(y = 0.5, shape = groups), size = 4)+
  theme_void()+
  guides(fill = FALSE)+
  theme(legend.position = "bottom")

data %>% 
  mutate(split = ifelse(groups == "e", "train", "test") %>% fct_relevel(c("train", "test"))) %>% 
  ggplot(aes(x = time, fill = split))+
  geom_bar()+
  theme_void()+
  theme(legend.position = "none",
        axis.text.x = element_text())+
  labs(x = "time")
