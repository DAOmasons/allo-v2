# Grant Ships

Grant Ships introduces a meta-framework that provides a methodical approach to grants programs. It enables communities to allocate funds for grants distribution, designate facilitators to oversee the process and delegate grant recipient screening and grant allocation to one or more subdaos or individuals referred to individually as a "Grant Ship". The technical architecture and interactions within the system are explained below.

## Table of Contents

- [Grant Ships](#grant-ships)
  - [Table of Contents](#table-of-contents)
- [Diagram](#diagram)
- [Contract Overview](#contract-overview)
  - [GameManagerStrategy Contract (`GameManagerStrategy.sol`)](#game-manager-strategysol)
  - [GrantShipStrategy Contract (`GrantShipStrategy.sol`)](#grant-ship-strategysol)
- [Key Functionality and Interactions](#key-functionality-and-interactions)
  - [TBD:](#tbd)
- [Roles and Actors](#roles-and-actors)
- [User Flows](#user-flows)
  - [GameManagerStrategy Contract](#game-manager-strategy-contract)
  - [GrantShipStrategy Contract](#grant-ship-strategy-contract)
- [Conclusion](#conclusion)

## Diagram

![Grant Ships Swim Lanes](img/GrantShips-SwimLanes.png)

## Contract Overview

<table>
    <thead>
        <tr>
            <th>Contract</th>
            <th>Purpose</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>GameManagerStrategy.sol</td>
            <td>- Initiates the Game</br>- Accepts applications for Grant Ship Operators</br>- Initializes funding sub pools for individual Grant Ships</br>- Allocate and distribute funds to sub pools</td>
        </tr>
        <tr>
            <td>GrantShipStrategy.sol</td>
            <td>- Accepts applications from potential Grant Recipients<br>- Allows Grant Ship Operators to review and approve Recipients<br>- Allows Recipients to submit milestones for review and funding</td>
        </tr>
    </tbody>
</table>

### GameManagerStrategy Contract (`GameManagerStrategy.sol`)

The `GameManagerStrategy` contract serves as the foundation for the Grant Ships game. It allows Game Facilitators to set the initial parameters, review Grant Ship applicants and initiate the game when Grant Ship Operators have been selected. It has permission to make calls into the GrantShipStrategy and distribute funds.

Every major action in the contract emits an event, creating records that can be aggregated into feeds. In each function where the caller is making a decision, an optional parameter `Metadata _reason` is included. The UpdatePosted event allows GameFacilitators to post arbitrary data to their feed, usually corresponding to game-wide events.

### GrantShipStrategy Contract (`GrantShipStrategy.sol`)

The `GrantShipStrategy` contract is also an Allo Strategy with associated funding pool. Multiple instances are initialized by `GameManagerStrategy` - one for each Grant Ship. Once the game is started the contract handles applications from potential Grant Recipients and the submission of milestones.

Game Facilitators can make calls into this contract to flag a Grant Ship with Yellow or Red Flags. Yellow Flags are like notes or warnings that go into the public feeds. Red Flags lock down Ship operations until the flag is resolved.

Like GameManagerStrategy, GrantShipStrategy offers a `Metatdata _reason` parameter for each function where the caller would be making a decision. Each GrantShip also has its own `_postUpdate` function for posting arbitrary data to their feed. This function gates the role to either a Grant Recipient, a Ship Operator, or a Game Facilitator. It will also detect the caller's role and tag the post accordingly, allowing for easy indexing later on.

// Note: Is the section below a list of the key interactions involved with both contracts? If so, are these sections meant to be filled in eventually? If so, I can add to this.

## Key Functionality and Interactions

### Game Initialization

// Note: This is a big one, and a great use for the docs here. There's a lot of preconfig required to set up the game, for example, structuring the Hats Tree.

### Grant Ship Operator Applications and Approval

### Grant Recipient Applications and Approval

Grant Ship and Grant Recipient registration happens through the registerRecipient function in `BaseStrategy.sol` as part of the Allo registration process. Registration requires the caller to have an Allo registry account.

In `GameManagerStrategy` a call to registerRecipient is made to register potential new Grant Ships. If the applicant is a member of the passed registry profile, the call includes valid metadata and the recipient has not been registered previously, then a new Recipient entry is created and added to the recipients list and a Registered event is emitted.

A subsequent call to reviewRecipient by the Game Facilitator sets a recipient's status to `GameStatus.Accepted` or `GameStatus.Rejected` and emits a corresponding `RecipientAccepted` or `RecipientRejected` event. When a Grant Ship/Recipient is approved in this way,`_createShip` is called which launches a new funding pool by calling `_allo.createPoolWithCustomStrategy` with `GrantShipStrategy.sol` specified as the strategy by `GrantShipFactory`. A `ShipLaunched` event is emitted.

### Game Facilitators apply yellow or red flags

Once the Grant Ships are launched (using `GrantShipStrategy.sol`) the Game Facilitator has permission to issue a Yellow or Red Flag by calling the `issueFlag` in GrantShipStrategy.

### GameManager can deploy other types of GrantShips.

// Todo: Not currently in use, but we can adapt other Allo strategies and turn them into GrantShips. Definitely worth mentioning.

### Content Generation

// With off-chain tools, we usually have the luxury of having user generated content to see 'why' a user initiated a certain action. In many governance apps, we usually don't have that luxury. However, with grants programs, the demand for good record-keeping is very high. This usually creates a large burden for program managers, who have to access data across many different silos. These contracts aim to make record-keeping a passive side-effect. Full transparency is not only necessary for playing the game, it's a strategy for success.

### Security & Capture Resistance

// Todo: Explain Hats revokability, the pool withdraw process, and place a link to Spencer's original article there as well.

## Roles and Actors

The Grant Ships game delegates distinct and revokable roles to participants using [Hats protocol](https://github.com/Hats-Protocol/hats-protocol) to foster efficient operations:

- **Game Facilitators:** Responsible for initalizing the game, selecting Grant Ships and approving fund allocations. Game Faciliators have the option to apply and resolve yellow or red flags to Grant Ships which will go on the Grant Ships record. Red flags lock down ship operations until resolved.
- **Grant Ship Operator:** Operators approve Grant Recipients and their submitted milestones. They submit fund allocations for Game Faciliator review, and distribute the allocated funds when milestones are submitted.
- **Grant Recipients:** Grant Recipients apply for funding and are either approved or rejected by the Grant Ship Operators. They can also submit milestones for funding.

![Hats Roles Diagram](img/GrantShips-HatsRoles.png)

## User Flows

### GameManagerStrategy Contract

- **Functionality:** The `GameManagerStrategy` Contract extends Allo `BaseStrategy` to allow Game Facilitators to initialize the Grant Ships game, accept applications from potential Grant Ships, approve or reject Grant Ship applicants, allocate and distribute funds to approved Ships and emit events.
- **Interactions:**
  - The `GameManagerStrategy` contract interacts with the `GrantShipStrategy` contract to initialize the subpools.
  - The `GameManagerStrategy` contract interacts with `Hats` to check whether caller addresses are currently the wearer of a Hats Protocol hat and so authorized as a Game Facilitator.
- **User Flows:**
  - Grant Ships apply to become recipients and managers of sub pools through `GrantShipStrategy`
  - Game Facilitators start new game rounds, approve or reject Grant Ship applications, create sub-pools and managing Grant Ships, allocate and distribute funds to subpools, start and stop funding rounds and recover/withdraw funds from the contract.
  - Game Facilitators can post updates, emitting UpdatePosted events from the contract
- **Events:**
  - RoundCreated, ShipLaunched, RecipientAccepted, RecipientRejected, GameActive, GameManagerInitialized, UpdatePosted

### GrantShipStrategy Contract

- **Functionality:** The `GrantShipStrategy` Contract extends Allo `BaseStrategy` to allow Grant Ships to accept applications from potential grant recipients, review applications, approve applications by allocating funds and receive milestone declarations from Grant Recipients. It allows Grant Recipients to submit milestones for funding which can be rejected or funded by the Grant Ship.
- **Interactions:**
  - The `GrantShipStrategy` contract interacts with the `GrantShipStrategy` contract to initialize the subpools.
  - The `GrantShipStrategy` contract interacts with `Hats` to check whether caller addresses are currently the wearer of a Hats Protocol hat and so authorized as a Game Facilitator or Ship Operator
- **User Flows:**
  - Potential grant recipients apply to be approved by Grant Ship Operators to receive funds
  - Game Faciliators issue yellow or red flags to Grant Ships
  - Game Facilitators allocate funds from the GrantShip funding pool for a particular recipient w/milestones
  - Grant Ships distribute allocated funds when milestones are submitted and approved by grant recipients
  - Game Facilitators, Grant Ship Operators and Recipients can post updates, emitting UpdatePosted events from the contract
- **Events:**
  - RecipientStatusChanged, MilestoneSubmitted, MilestoneStatusChanged, MilestoneRejected, MilestonesSet, FlagIssued, FlagResolved, MilestonesReviewed, PoolWithdraw, PoolFunded, UpdatePosted

## Conclusion

The Grant Ships project is a reorganization of traditional grants program to provide decentralized fund allocation, distribution, transparency and accountability. By employing revokable roles the administering community retains control, and responsibilities are divided among multiple roles so that players can focus on what they do best.

// Note: We allude to revokable roles here, but I think it would be good to include a capture resistance section somewhere in this document and demonstrate how we address this in detail. We should explain Hats revokability, the pool withdraw process, and place a link to Spencer's original article there as well.