# Retrospective and New Development Plan

## Retrospective

Over the past development cycles, we encountered several challenges:

- **Progress Delays:** We have not been making the expected progress on core features. Integration of Firebase, video services, and UI components has taken longer than anticipated.

- **Styling and UI Refinement:** While we made improvements to the app styling, the visual design and user experience still feel inconsistent and lack cohesion.

- **Scope Creep and Prioritization:** There have been shifting priorities and unclear definitions of our MVP scope. This has led to spreading our efforts too thinly across different functionalities.

- **Team Communication:** Feedback loops and code reviews have been slower than expected, contributing to misunderstandings about feature requirements.

- **Technical Hurdles:** Integration with Firebase and handling asynchronous tasks in Flutter have posed unexpected challenges which slowed our progress.

## Reflection

From these challenges, we learned the importance of clear prioritization, regular check-ins, and breaking tasks into smaller, manageable increments. We also recognized the need for a simpler, well-defined MVP before extending features further.

## New Development Plan

### 1. Redefine the MVP Scope

- **Core Features:** Focus solely on the essential user stories for a Minecraft video consumer:
  - **Video Upload:** Allow users to upload Minecraft videos.
  - **Video Feed:** Display a curated list of Minecraft videos in a dynamic feed.
  - **Video Search:** Enable users to search for videos with a view that lists actual videos matching the query.
  - **User Profiles:** Showcase user details, including:
    - Video Playlists (collections of favorite videos)
    - Uploaded Videos
    - Following (list of users the current user follows)

- **Styling and UX:** Finalize a consistent dark theme with vibrant accents. Lock down the UI design before adding new features.

### 2. Reorganize and Prioritize Tasks

- **Task Breakdown:** Divide the development process into smaller sprints:
  - **Sprint 1:** Finalize design (UI/UX consistency, styling, typography) and core Firebase integrations (auth, video feed).
  - **Sprint 2:** Implement video interactions (like, comment features) and complete user profiles.
  - **Sprint 3:** QA, bug fixing, and preparing for deployment.

- **Regular Stand-ups and Retrospectives:** Schedule short daily stand-ups and end-of-sprint retrospectives to review progress and pivot quickly if needed.

### 3. Improve Process and Communication

- **Documentation:** Maintain clear documentation for features and coding standards.
- **Code Reviews:** Establish regular code review sessions and ensure that team feedback is promptly addressed.
- **Backlog Management:** Use a project management tool to track tasks and prioritize backlog items effectively.

### 4. Short-Term Milestones & Deliverables

- **Immediate Next Steps:**
  1. Hold a team meeting to review this retrospective and new plan.
  2. Finalize the updated MVP feature list with clear, prioritized user stories.
  3. Reassign and break down tasks into our project management tool.
  4. Design a consistent UI theme and lock it down (refine our current dark theme with vibrant accents).

- **Next Milestone (1 Week):** Complete the base framework (authentication, video feed display, and consistent styling) for an internal demo.

### 5. Future Enhancements

After achieving the core MVP, we will consider additional features like:

- Advanced video interactions (playlists, subscriptions, notifications).
- AI-driven enhancements for video processing and customization.
- Extended analytics and user feedback mechanisms.

## Final Thoughts

This retrospective and new development plan should serve as a roadmap to help us refocus our efforts and streamline our processes. The priority is to deliver a stable, well-designed MVP before expanding the feature set. 