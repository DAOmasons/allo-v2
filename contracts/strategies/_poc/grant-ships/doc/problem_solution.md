# Grant Ships Problem/Solution Overview

This document aims to outlines the problems we see with traditional grants programs and how Grant Ships provides solutions to each.

## Problem

1. **Friction and Uncertainty** > Qualified builders often find too much friction and uncertainty to justify pursuit of a web3 grant.

   - As a builder in the web3 grants scene, a lot of time and effort is spent identifying communities with funding opportunities, researching what it is they need, building reputation, building network connections, proving qualifications and generating proposals.
   - It's difficult to justify investing this time and effort when outcomes are uncertain. Unless there is a clear path to getting a yes or no answer, most talent won't even enter the scene.

1. **Chaos.** Grant administrators spend a lot of time in 'Spreadsheet Hell'- Updating records and tracking transactions that are scattered through many walled gardens, among many organizations.
   - A major challenge for grants programs is tracking and publishing funding decisions, outcomes, communications, timelines and more.
   - The need to keep these records up to date for transparency purposes creates a lot of overhead that is currently done manually (usually in the depths of spreadsheet hell).
1. **Waste**. Repeated actions that are performed among many circles could be delegated to discreet roles.
   - Allocators are often overly focused on creating systems for recipient applications and tracking distributions in spreadsheets. They should focus on allocating to great projects, not paperwork.
   - Every grants program has administrative overhead for these systems, when it could be done just once per community (e.g. Arbitrum)
1. **Ignorance**. We have no way of knowing what the best ways of allocating capital are or who the best allocators are.
   - Within a given ecosystem there is typically one grant-giving organization and one approach, so it is difficult to compare it to alternatives.
   - Without a regular assessment of performance, we aren't actually determining who is doing a good job.
1. **Overhead.** Using a yes or no Vote for each Grant has way too much overhead.

   - It's not practical to expect every voter to gain context and make informed votes on every grant.
   - Grant recipients each have massive overhead to educate the community on why their proposal is worthwhile and also on the outcomes after funding.
   - The high overhead costs inhibit the provision of numerous voter decision points, making more granular decisions impractical.

1. **Risk.** Choosing to delegate large amounts of capital to Grants Councils does not guarantee that the Grants council will be effective or trustworthy.
   - Grants councils are entrusted with a lot of power and authority over funding decisions and are often also responsible for reporting on their own outcomes. Capture is possible, incompetence is possible, oversight is difficult.
1. **No budgets** Voting for every issuance of Grant funds, whether to a group of Allocators, or to an individual project assures that setting a regular budget in DAOs is impossible.
   - Only 'emergent' budgets are possible. i.e. Let's see what the DAO decides to spend and say that's the budget.
   - Bulky grant proposals to the DAO create uncertainty and irregularity in funding rhythms. This makes budgeting difficult or impossible, as the DAO at any time could decide to fund a larger or smaller grants program, and that could change at any time with a new passed proposal.

## How The Product Solves these Problems

### Friction and Uncertainty

> Qualified builders often find too much friction and uncertainty to justify pursuit of a web3 grant.

**Transparency and Clarity**

- GameManagerStrategy and GrantShipStrategy provide a structured, predictable and transparent step by step process embedded in code.
- Clearly defined roles and simple rules defined onchain dispel uncertainty by providing transparent insight into the grants process.
- The Grant Ships Dashboard UI allows candidates to fully understand the opportunities in front of them.
- The Dashboard UI shows candidates their next steps to receive a timely yes or no on a funding.

### Chaos and Spreadsheet Hell

> Grant administrators spend a lot of time in 'Spreadsheet Hell'- Updating records and tracking transactions that are scattered through many walled gardens, among many organizations.

**Automatic Lifecycle Documentation**

- By utilizing Allo's metadata standard, Grant Ships makes record-keeping a _passive side effect_ of giving grants.
- All lifecycle events are documented automatically and recorded onchain (with structured metadata on IPFS) and presented in the Dashboard.
  - Example events:
    - Funding round begins
    - Grant Ship (allocator) approved and funded
    - Project proposals received
    - Applicant acceptance/rejection
    - Milestones reviewed
    - Fund distributions
    - Project updates and work submitted
    - As-needed updates by facilitators, allocators or recipients.

### Waste

> Repeated actions that are performed among many circles could be delegated to discreet roles.

**Role Delegation**

- We integrated Hats Protocol with Allo in GameManagerStrategy and GrantShipStrategy.
- This gives us the ability to define organizational roles in the code.
- Roles allow us to divide labor among different function calls. We now know, through immutable code, which role is responsible for which steps in the grant-giving process.

### Ignorance

> We have no way of knowing what the best ways of allocating capital are or who the best allocators are.

**Isolation of Variables**

- GameManagerStrategy contract provides an "A/B" test environment where we can compare allocation practices.
- All Ships start at the same time. All Ships operate within the same rules and produce comparable, documented results by the game end.
- This provides a cleaner way to compare DAO allocation mechanisms and the efficacy of allocators.

**Experimentation**

- The GameManagerStrategy contract can handle many types of Grant Ship allocation strategies (using modified Allo Strategies).
- Currently, we only have one Grant Ship Strategy - `GrantShipStrategy.sol`, based on milestones.
- GameManagerStrategy contract will allow us to adapt other Allo strategies into GrantShips for additional experimentation.

### Overhead

> Using a yes or no Vote for each Grant has way too much overhead.

**Clear Decisions**

- Grant Ships provides simple decision paths for the voter without the need for extensive study.
- We replace massive context proposal voting with a series of smaller, targeted contextual votes.

**Structure**

- Rhythmic governance cycles create predictable, palatable demand for voter attention.
- Hats Protocol roles span multiple contracts, allowing a greater degree of specialization; people can focus on what they're good at without duplicating work.

**Transparency**

- The Dashboard UI provides everything a voter needs to gain context and make decisions, reducing research burden.

### Risk

> Choosing to delegate large amounts of capital to Grants Councils does not guarantee that the Grants council will be effective or trustworthy.

**Accountability through Transparency**

- Transparent allocation provides incentive to be effective and trustworthy.
- Broadcasting all meaningful events within the grant giving process provides signal to the DAO for accountability purposes.

**Revokable Privileges**

- Grant Ships' integration with Hats Protocol provides revokable privileges, reducing risk of capture and "sunk cost loyalty" - see Spencer Graham's ['Anticapture'](https://spengrah.mirror.xyz/f6bZ6cPxJpP-4K_NB7JcjbU0XblJcaf7kVLD75dOYRQ)
- Game Facilitators and Grant Ships can all be suspended or replaced by a DAO vote as needed.

**Reasonable Safeguards**

- Game Facilitators screen and approve allocator Grant Ships and, once approved, all Recipient fund allocations for those Grant Ships.
  - This can ensure DAO KYC/KYB standards are met for every recipient, without relying on each allocator to do it right.
- Checks and balances are provided because Game Faciliators approve grant recipient _allocations_, but Grant Ships handle _distributions_ at their discretion.
  - With Allo, Allocation and Distribution are distinct actions.
    - Allocation earmarks the funds
    - Distribution disburses them.
- Game Facilitators can apply Yellow or Red Flags to a Grant Ship.
  - Yellow Flags are like a verbal warning, creating an attestation of the event with context for voter review.
  - Red Flags also create an attestation of the event with context but additionally lock down the ship's ability to distribute funds until the flag is resolved.

### No Budgets

> Voting for every issuance of Grant funds, whether to a group of Allocators, or to an individual project assures that setting a regular budget in DAOs is impossible.

**Rhythm and Cadence**

- The GameManagerStrategy contract can enforce a regular cadence of grant giving - a defined start time and end time for each round - that could be tied to different funding cycles (i.e. monthly, quarterly)
- This creates a system where you could allocate a portion of sequencer fees to grants creating a grants funding streams.

**Budgets and Funding Faucets**

- Grant Ships functions like a funding faucet that can be filled by the DAO for eventual distribution.
- Once the pool is funded, as many Grant Ships in whatever variety required can be spun up to handle distribution to individual recipients.
  - With expansion of Grant Ships it's reasonable to predict that fewer and fewer Yes or No grant proposals will need to go to Arbitrum DAO.
  - Instead, funding streams could be designated for the Grant Ships funding pool and grants programs could apply to be a Grant Ship and receive funding.
  - Grant recipients can apply to these Grant Ships to receive funds.
  - Voters maintain influence and control through the regular voting and revokable privilege systems.
  - This allows the DAO to create a budget for grants, that can be increased or decreased as needed.

**Grants DAO**

- Grant Ships is kind of like the OS for a Grants SubDAO
- Hat's role-based permissions shine through
  - You don't want everybody to vote on heavy proposals, you want to delegate responsibility to trusted actors and retain power to revoke that with the DAO.
- Creates a reasonable objection/alternative to a heavyweight grants proposal - "Why not just spin up a new Grant Ship?"

## System Roles and Major Action Diagram

![GrantShips-SwimLanes(2)](https://hackmd.io/_uploads/ryfVumOKa.png)
