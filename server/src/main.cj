package campus

import campus.api.*
import campus.domain.*
import campus.repository.*
import campus.service.*

/**
 * 命令行冒烟演示。
 *
 * 它和未来 HTTP 适配器调用的是同一套 CampusApi，
 * 因此可以在不启动网络、不连数据库的情况下验证核心业务。
 *
 * 运行：cjpm run（或在 DevEco / VSCode 的仓颉插件里运行）
 */
main(): Int64 {
    let now = 1_780_000_000_000
    let clock = FixedClock(now)
    let repos = MemoryRepositories()
    seedDemoData(repos, now)

    let tokens = InMemoryTokenService()
    let auth = AuthService(repos.users, repos.clubs, DemoPasswordVerifier(), tokens)
    let activityService = ActivityService(repos.clubs, repos.activities, repos.tx, clock)
    let clubService = ClubService(repos.users, repos.clubs, repos.tx, clock)
    let signupService = SignUpService(repos.activities, repos.signs, repos.messages, repos.tx, clock)
    let messageService = MessageService(repos.messages)
    let api = CampusApi(auth, activityService, clubService, signupService, messageService, repos.signs)

    runDemo(api)
    return 0
}

func printError(prefix: String, error: BizError): Unit {
    println("${prefix} ${ErrorDto(error.code, error.detail, "demo-request").toJson()}")
}

func runDemo(api: CampusApi): Unit {
    let studentLogin = api.login("student", "123456")
    match (studentLogin) {
        case Err(error) =>
            printError("LOGIN_ERR", error)
            return
        case Ok(response) =>
            println("LOGIN_OK ${response.toJson()}")
            match (api.authenticate(response.token)) {
                case None =>
                    println("AUTH_ERR token not found")
                    return
                case Some(actor) =>
                    runStudentFlow(api, actor)
            }
    }

    let leaderLogin = api.login("leader", "123456")
    match (leaderLogin) {
        case Ok(response) =>
            println("LEADER_LOGIN_OK ${response.toJson()}")
            match (api.authenticate(response.token)) {
                case Some(actor) => runLeaderFlow(api, actor)
                case None => println("LEADER_AUTH_ERR")
            }
        case Err(error) => printError("LEADER_LOGIN_ERR", error)
    }

    let adminLogin = api.login("admin", "123456")
    match (adminLogin) {
        case Ok(response) =>
            println("ADMIN_LOGIN_OK ${response.toJson()}")
            match (api.authenticate(response.token)) {
                case Some(actor) => runAdminFlow(api, actor)
                case None => println("ADMIN_AUTH_ERR")
            }
        case Err(error) => printError("ADMIN_LOGIN_ERR", error)
    }
}

func runStudentFlow(api: CampusApi, actor: Actor): Unit {
    println("ACTIVITIES ${api.listActivities().toJson()}")

    match (api.activityDetail(Some(actor), 1)) {
        case Ok(detail) => println("DETAIL ${detail.toJson()}")
        case Err(error) => printError("DETAIL_ERR", error)
    }

    let firstSignId = match (api.signUp(actor, 1, "demo-key-1")) {
        case Ok(receipt) =>
            println("SIGNUP_OK ${receipt.toJson()}")
            receipt.signId
        case Err(error) =>
            printError("SIGNUP_ERR", error)
            0
    }

    // 同一个幂等键重试：应该返回同一条报名记录，不会重复扣名额。
    match (api.signUp(actor, 1, "demo-key-1")) {
        case Ok(receipt) =>
            println("RETRY_SAME_KEY ${receipt.toJson()}")
            println("IDEMPOTENT ${receipt.signId == firstSignId}")
        case Err(error) => printError("RETRY_ERR", error)
    }

    // 换一个键再次报名：应该被 ALREADY_SIGNED 拦住。
    match (api.signUp(actor, 1, "demo-key-2")) {
        case Ok(receipt) => println("DUPLICATE_UNEXPECTED ${receipt.toJson()}")
        case Err(error) => printError("DUPLICATE_EXPECTED", error)
    }

    match (api.cancel(actor, 1)) {
        case Ok(receipt) => println("CANCEL_OK ${receipt.toJson()}")
        case Err(error) => printError("CANCEL_ERR", error)
    }

    println("MESSAGES ${api.listMessages(actor).toJson()}")
}

func runLeaderFlow(api: CampusApi, actor: Actor): Unit {
    let signStart = 1_780_000_000_000
    let day = 24 * 3600 * 1000
    let draft = api.createActivityDraft(
        actor,
        1,
        "社团例会：端云边界怎么划",
        "用一个报名业务讲清楚 ArkTS、仓颉服务、数据库各自负责什么。",
        "实验楼 A305",
        20,
        signStart,
        signStart + 2 * day,
        signStart + 3 * day
    )
    match (draft) {
        case Ok(activity) =>
            println("DRAFT_OK ${activity.toJson()}")
            match (api.publishActivity(actor, activity.activityId)) {
                case Ok(published) => println("PUBLISH_OK ${published.toJson()}")
                case Err(error) => printError("PUBLISH_ERR", error)
            }
        case Err(error) => printError("DRAFT_ERR", error)
    }
}

func runAdminFlow(api: CampusApi, actor: Actor): Unit {
    // 先从学生视角申请一个新社团，再由管理员审核。
    match (api.login("student2", "123456")) {
        case Ok(response) =>
            match (api.authenticate(response.token)) {
                case Some(studentActor) =>
                    match (api.createClub(studentActor, "校园摄影社", "记录校园活动与社团日常。")) {
                        case Ok(club) =>
                            println("CLUB_CREATED ${club.toJson()}")
                            match (api.approveClub(actor, club.clubId)) {
                                case Ok(approved) => println("CLUB_APPROVED ${approved.toJson()}")
                                case Err(error) => printError("CLUB_APPROVE_ERR", error)
                            }
                        case Err(error) => printError("CLUB_CREATE_ERR", error)
                    }
                case None => println("STUDENT2_AUTH_ERR")
            }
        case Err(error) => printError("STUDENT2_LOGIN_ERR", error)
    }
}
