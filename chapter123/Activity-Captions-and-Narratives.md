# 3.6 ACTIVITY DIAGRAM — Captions and Narratives

Captions and narrative paragraphs for the 7 Activity Diagram figures.
Captions sit **above** each figure (matching your reference document), narratives go on the
page immediately after. Figure numbers continue from your DFD figures (Figures 5–14),
so the Activity Diagram section runs from Figure 15 to Figure 21.

---

## Figure 15

**Caption:** Figure 15: Activity Diagram (Member Login and Registration)

**Narrative:**

> Figure 15 shows the activity diagram of the member login and registration process of the
> proposed system of Triple J Fitness Center. The process begins when the Member opens the
> fitness application and enters an email address and a password. The system first determines
> whether the Member has an existing registered account.
>
> If the Member is not yet registered, the registration form is presented, where the Member
> fills out the required personal and membership details. The registration details are
> submitted, the account is created and stored in the User Profiles, and the Member receives
> an account confirmation before returning to the login step.
>
> If the Member is already registered, the system validates the entered credentials against
> the stored account records. When the credentials are valid, the system displays the member
> dashboard and the process ends. When the credentials are invalid, an error message is
> displayed and the Member is returned to the login step to re-enter the email and password.
> This automated validation replaces the manual checking of member records in the existing
> system.

---

## Figure 16

**Caption:** Figure 16: Activity Diagram (Workout Logging with Exercise Tracking)

**Narrative:**

> Figure 16 shows the activity diagram of the workout logging process of the proposed system
> of Triple J Fitness Center. The process begins when the Member starts a workout session and
> selects an exercise from the exercise catalog. For each selected exercise, the Member enters
> the number of sets, the number of repetitions, and the duration of the exercise.
>
> After the exercise details are entered, the system determines whether the Member will record
> a proof video. If a proof video is recorded, the Member captures or uploads the video before
> proceeding; otherwise the process continues directly. The system then retrieves the MET value
> of the selected exercise from the MET Exercise Catalog and computes the calories burned based
> on the exercise duration and the recorded body weight of the member.
>
> The system then determines whether the Member will add another exercise. If yes, the process
> returns to the exercise selection step; if no, the Member finishes the session. All recorded
> entries are saved into the Workout Logs, and the system displays the workout summary together
> with the total calories burned, which ends the process.

---

## Figure 17

**Caption:** Figure 17: Activity Diagram (QR Code Check-In and Check-Out)

**Narrative:**

> Figure 17 shows the activity diagram of the QR code check-in and check-out process of the
> proposed system of Triple J Fitness Center. The process begins when the Member opens the
> application and taps the check-in button, which activates the QR scanner. The Member scans
> the QR code posted at the gym, and the system validates whether the scanned code corresponds
> to a recognized gym location.
>
> If the QR code is invalid, an error message is displayed and the Member is returned to the
> scanning step. If the QR code is valid, the system records the check-in timestamp into the
> Check-In and Attendance Records, displays a checked-in confirmation, and the Member performs
> the workout.
>
> After the workout, the Member taps the check-out button. The system records the check-out
> timestamp, updates the attendance record, and displays a checked-out confirmation, which
> ends the process. This automated attendance flow replaces the manual log sheets used in the
> existing system.

---

## Figure 18

**Caption:** Figure 18: Activity Diagram (Meal Logging and AI Food Analysis)

**Narrative:**

> Figure 18 shows the activity diagram of the meal logging and AI food analysis process of the
> proposed system of Triple J Fitness Center. The process begins when the Member opens the meal
> logging page and enters the meal details containing the food name, the meal type, and the
> estimated calories. The system then determines whether the Member will upload a food
> photograph.
>
> If a photograph is uploaded, the captured or uploaded image is sent together with a nutrition
> query to the Google Gemini API, which returns the recognized food item. If no photograph is
> uploaded, the process proceeds directly using the manually entered meal details.
>
> The system computes the nutrient breakdown by retrieving the food composition data from the
> Nutrition Foods, generates a food recommendation, and displays the nutrient breakdown
> together with the recommendation to the Member. Finally, the meal record is saved into the
> Meal Logs, which ends the process.

---

## Figure 19

**Caption:** Figure 19: Activity Diagram (Dashboard View)

**Narrative:**

> Figure 19 shows the activity diagram of the dashboard view process of the proposed system of
> Triple J Fitness Center. The process begins when the user logs in to the system, and the
> system determines the role of the logged-in user.
>
> When the user is a Member, the dashboard presents the workout history, the BMI trend, and the
> predicted fitness progress. When the user is a Trainer, the dashboard presents the assigned
> members, the retention risk alerts, and the plan completion status. When the user is an
> Admin, the dashboard presents the attendance reports, the analytics summary, and the inactive
> member alerts.
>
> After the role-specific selections are made, the system retrieves the corresponding data from
> the Workout Logs, the Body Measurements, the Predictions, the Goal Plans, the Check-In and
> Attendance Records, and the Admin Logs, and displays the dashboard containing the charts and
> the real-time status, which ends the process.

---

## Figure 20

**Caption:** Figure 20: Activity Diagram (Trainer Feedback and Member Rating)

**Narrative:**

> Figure 20 shows the activity diagram of the trainer feedback and member rating process of the
> proposed system of Triple J Fitness Center. The process begins when the Trainer selects a
> member and reviews the workout logs and progress of that member. The Trainer provides written
> feedback, which the system saves into the Trainer Feedback, and the system sends a
> notification to the Member.
>
> The Member views the feedback and chooses whether to rate the trainer. If the Member provides
> a star rating from one to five, the system saves the rating; otherwise the process proceeds
> directly. The system then displays the feedback confirmation to the Member, which ends the
> process. This closed-loop feedback mechanism replaces the informal verbal advice of the
> existing system with recorded and rated feedback.

---

## Figure 21

**Caption:** Figure 21: Activity Diagram (Goal Setting and Plan Creation)

**Narrative:**

> Figure 21 shows the activity diagram of the goal setting and plan creation process of the
> proposed system of Triple J Fitness Center. The process begins when the system analyzes the
> progress trend of the member using the workout history, the measurement history, and the
> nutrition history retrieved from the Workout Logs, the Body Measurements, and the Meal Logs.
>
> Using the analyzed trend, the system generates the predicted fitness progress, assesses the
> retention risk, and notifies the Trainer of the risk result. The adjusted goal suggestion is
> displayed to the Member, who sets or refines the fitness goal, and the goal is saved into the
> Goal Plans.
>
> The Trainer reviews the member goal and creates the plan consisting of the food plan and the
> exercise plan, which is saved into the Goal Plans. The system continuously monitors the plan
> completion and displays the completion status to the Trainer and the Member, which ends the
> process.
