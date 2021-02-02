# Opening

**Possible quotes on time:**

* “Time is a storm in which we are all lost” – William Carlos Williams
* “Time changes everything except something within us that is always surprised by change.” – Thomas Hardy

In many, if not most business and organizational settings time matters in some way or the relationships in your data may change with time. Hence, even if you are not doing forecasting, and may be building models in traditional regression and classification contexts, you should know how to properly structure your problems so that variation across time is considered.

The first part of this talk is going to be a lot about types of data splits and specifically doing these across time. The second part is then going to be examples on creating time based and non-time based features. And then bring this all together to compare model performance.

# Data split

Most common type is for the data to be allocated randomly or randomly but controlled so that the target is similar distributed in the two sets.
If your data is not independent – however—you likely will not split it randomly but in some way that will control for this lack of independence (prevents a potential source of data leakage – when information outside the training dataset is used to create the model). 

*The two most common approaches to this are:*

1. Splitting by some grouping variable  
    a. E.g. customer transaction data, where you have multiple records from the same customer  
2. Splitting by time  
    a. This is obviously necessary when you are doing forecasting, but it is also important when working on typical regression or classification problems and where you think the relationships in your data may change according to some time component.  
    b.Also in most business situations any model you build will be built at one point in time and then deployed on data at a different point in time (this separation may be an hour, a week, a quarter) – but such a split in training and evaluation mirrors the model build  production separation more closely  
      i.	For this reason I am a big advocate of using this type of split in many if not most business contexts as it often provides a more reasonable picture of what kind of performance you should expect.  
1.	So that when you are presenting your results to stakeholders, you don’t end-up giving a false sense of the type of accuracy you can expect from your model.

*Drawbacks to time-based data splits:*

* It takes more thought and effort
    * In some cases your data is at least mostly independent across time, so the extra thought and effort isn’t necessary
* While performance estimates may be off, the model selection may still end-up the same
    * However, in cases where you are using more sophisticated model types, you may be more likely to overfit on some time-based peculiarity…
* Sacrifice data in some splits when doing cross-validation
    * Will talk about…

*What is cross-validation?*  

* You take different splits on your data such that your testing set is composed of different observations for each split.

![](https://image.slidesharecdn.com/granada-140207061551-phpapp01/95/automatic-time-series-forecasting-71-638.jpg?cb=1392426574)

* This is an example of 5 fold cross-validation, so there are 5 different data splits, each of which has a different set of observations in the testing-set 
* (when doing cross validation you sometimes call this the training data in a split the “analysis” set and the testing data the “assessment” set – this distinguishes these splits from your more broad data splits
* For each of these splits you train a model using the analysis/training set, and then evaluate it on the assessment/testing set. You then take the average performance across each of these and take the average of the performance.
* In this case each observation ends-up in an analysis set 4 times and an assessment set once – see 3.4 Resampling in “Feature Engineering and Selection…” by Kuhn, Johnson: http://www.feat.engineering/resampling.html for alternatives
* (reveal 2nd part of image) OK, so this is the standard way of doing cross-validation when a random data split is appropriate, however let’s look at this in the time based setting
* In this case we’re doing 10-fold time-series cross validation
*	Now each split comes at the end of the dataset so that, in each split, everything prior is in the analysis/training data and a point (or multiple points) immediately after is in the assessment/testing data.
* Otherwise it works the same whereby we train the model on the analysis set, evaluate it on the assessment set, and then report on the average performance across the splits.
* This though demonstrates one of the downsides I’d mentioned – in some of these splits we have less data in our training window. Depending on the complexity of our model and the relationship it is trying to capture, this may hurt the performance.

*Why is cross-validation used:*

* Sometimes used to replace the need for a training-testing dataset
* Used in addition to a training-testing set, so that a lot of the evaluation steps without needing to touch your testing dataset
* May provide a better estimate of performance (as evaluated on multiple splits)
* Helpful for getting a sense of the variability in your performance metrics 
* Downsides: extra step of set-up, takes more time (as building many models)

This concludes the introduction of how to set-up our model training and evaluation windows. Namely the justification for using time based splits in business problems and the value of using cross-validation. Now let’s see an example:

# Overview of data 

*	For my examples will be using Wake County Inspections data that I pulled from their public API and cleaned-up a little.
    *	HSISID: code for individual restaurant
    *	… other features…
    *	Say we want to predict the expected food sanitation score for a restaurant
        *	Maybe this information would be valuable for prioritizing where/how frequently food inspections need to be performed.

# Example with `rsample` package

* Example with rsample::initial_time_split() (first arranging the data)
* The basics of the rsample::sliding_* functions that provide the methods for setting-up the cross-validation windows
* I will be focusing just on rsample::sliding_period(), can check-out the documentation __ for how to use the other functions (or really have more complete documentation on the slider package of which these are largely based)
* What gets created and extracting the individual parts…
    *Cau use on it’s own (e.g. by going through a for loop or map and generating these datasets separately)
    *Or can use with the rest of the tidymodels framework and not need to work with these particular parts.
* When creating the windows can be difficult to tell exactly how things are going to be set-up, so I made a couple helper functions for inspecting this.
    *One that prints the windows specific to your dataset
    *Another that plots these (that I just read-in from a public gist I have posted)

(probably not) Maybe add-in example with simple model building here…

# Feature Engineering

The thing I’ve not yet touched-on is how to do feature engineering in this context.

dplyr + slider and recipes packages

* Need to be just about as careful when creating features as when creating models to avoid data leakage (particularly depending on the complexity of your features)
* Need to do feature engineering in a way that respects these splits.
    * types of features
* Time-based features – build prior to data splits (essentially represents raw data inputs) (dplyr + slider)
* Derived features – build in a ‘recipe’ (recipes)
* me based features:
* For predicting the expected food inspection score, take a second to think to yourself which information may be useful for predicting food inspection score.
* Factors related to prior food inspection scores
    * Slider methods (explain slider):
        * Average general score for the last year up until that day
        * Average score for the restaurant over the last 3 years
    * Non-slider methods
        * Most recent score
        * How long ago the restaurant was open
        * How long since it’s last inspection
These values depend on previous values and may need to dip across data splits between analysis/assessment / training/testing sets in order to be calculated. Hence these might be done first. Then will create our data splits.
* Recipes based features
    * step_boxcox()
    * step_other()
    * step_novel()
* `recipes` also helpful for convenience (these could be created ahead of time as they will not contribute to data leakage, but is more convenient to have recipes handle it)
    * step_date()
    * step_rm()

# model Building

* Specify linear model using `workflows`
* (not shown) specify Random Forest and NULL model

Steps to build a model (note that could also tune hyperparameters or parts of the recipe – see tmwr.org or tidymodels.org).

# Evaluate

* Extract performance across splits
* Review performance both across and within splits
* Review average performance
* Also use paired t-test as indicator to check if any difference is 'real'
