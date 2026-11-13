package campus.api

import std.collection.*
import campus.domain.*
import campus.repository.*
import campus.service.*

/**
 * 业务门面：HTTP 适配器 / 单元测试 / 命令行演示都调用这里。
 *
 * 这一层只做「鉴权上下文 -> service -> DTO」的转换，不写业务规则，
 * 也不碰 SQL。真正的 HTTP 路由、JSON 反序列化放在 transport 层，
 * 这样端云之间的契约可以被单独测试。
 */
public class CampusApi {
    private let auth: AuthService
    private let activities: ActivityService
    private let clubs: ClubService
    private let signups: SignUpService
    private let messages: MessageService
    private let signs: SignRepository

    public init(
        auth: AuthService,
        activities: ActivityService,
        clubs: ClubService,
        signups: SignUpService,
        messages: MessageService,
        signs: SignRepository
    ) {
        this.auth = auth
        this.activities = activities
        this.clubs = clubs
        this.signups = signups
        this.messages = messages
        this.signs = signs
    }

    public func login(studentId: String, password: String): Outcome<LoginResponseDto, BizError> {
        match (auth.login(studentId, password)) {
            case Ok(result) =>
                succeed<LoginResponseDto>(LoginResponseDto(result.token, toUserDto(result.user)))
            case Err(error) => fail<LoginResponseDto>(error)
        }
    }

    public func authenticate(token: String): Option<Actor> {
        return auth.authenticate(token)
    }

    public func logout(token: String): Unit {
        auth.logout(token)
    }

    public func listActivities(): ActivityListDto {
        let items = ArrayList<ActivitySummaryDto>()
        for (activity in activities.listOpen()) {
            items.add(toActivitySummaryDto(activity, clubNameOf(activity.clubId)))
        }
        return ActivityListDto(items, "")
    }

    public func activityDetail(actor: Option<Actor>, activityId: Int64): Outcome<ActivityDetailDto, BizError> {
        match (activities.find(activityId)) {
            case None => fail<ActivityDetailDto>(notFoundError("ACTIVITY_NOT_FOUND", "活动不存在"))
            case Some(activity) =>
                let signed = match (actor) {
                    case Some(current) =>
                        match (signs.findActive(activityId, current.userId)) {
                            case Some(_) => true
                            case None => false
                        }
                    case None => false
                }
                succeed<ActivityDetailDto>(
                    toActivityDetailDto(activity, clubNameOf(activity.clubId), signed)
                )
        }
    }

    public func signUp(
        actor: Actor,
        activityId: Int64,
        idempotencyKey: String
    ): Outcome<SignUpReceiptDto, BizError> {
        match (signups.signUp(actor, activityId, idempotencyKey)) {
            case Ok(receipt) => succeed<SignUpReceiptDto>(toSignUpReceiptDto(receipt))
            case Err(error) => fail<SignUpReceiptDto>(error)
        }
    }

    public func cancel(actor: Actor, activityId: Int64): Outcome<SignUpReceiptDto, BizError> {
        match (signups.cancel(actor, activityId)) {
            case Ok(receipt) => succeed<SignUpReceiptDto>(toSignUpReceiptDto(receipt))
            case Err(error) => fail<SignUpReceiptDto>(error)
        }
    }

    public func listSignUps(actor: Actor, activityId: Int64): Outcome<ArrayList<SignRecord>, BizError> {
        return signups.listSignUps(actor, activityId)
    }

    public func listClubs(): ClubListDto {
        let items = ArrayList<ClubDto>()
        for (club in clubs.listActive()) {
            items.add(toClubDto(club))
        }
        return ClubListDto(items)
    }

    public func listMessages(actor: Actor): MessageListDto {
        let items = ArrayList<MessageDto>()
        for (message in messages.list(actor)) {
            items.add(toMessageDto(message))
        }
        return MessageListDto(items)
    }

    public func markRead(actor: Actor, messageId: Int64): Outcome<Bool, BizError> {
        return messages.markRead(actor, messageId)
    }

    public func createActivityDraft(
        actor: Actor,
        clubId: Int64,
        title: String,
        description: String,
        location: String,
        maxCount: Int64,
        signStart: Int64,
        signEnd: Int64,
        activityTime: Int64
    ): Outcome<ActivityDetailDto, BizError> {
        match (activities.createDraft(
            actor,
            clubId,
            title,
            description,
            location,
            maxCount,
            signStart,
            signEnd,
            activityTime
        )) {
            case Ok(activity) =>
                succeed<ActivityDetailDto>(
                    toActivityDetailDto(activity, clubNameOf(activity.clubId), false)
                )
            case Err(error) => fail<ActivityDetailDto>(error)
        }
    }

    public func publishActivity(actor: Actor, activityId: Int64): Outcome<ActivityDetailDto, BizError> {
        match (activities.publish(actor, activityId)) {
            case Ok(activity) =>
                succeed<ActivityDetailDto>(
                    toActivityDetailDto(activity, clubNameOf(activity.clubId), false)
                )
            case Err(error) => fail<ActivityDetailDto>(error)
        }
    }

    public func createClub(actor: Actor, clubName: String, intro: String): Outcome<ClubDto, BizError> {
        match (clubs.createClub(actor, clubName, intro)) {
            case Ok(club) => succeed<ClubDto>(toClubDto(club))
            case Err(error) => fail<ClubDto>(error)
        }
    }

    public func approveClub(actor: Actor, clubId: Int64): Outcome<ClubDto, BizError> {
        match (clubs.approveClub(actor, clubId)) {
            case Ok(club) => succeed<ClubDto>(toClubDto(club))
            case Err(error) => fail<ClubDto>(error)
        }
    }

    private func clubNameOf(clubId: Int64): String {
        match (clubs.find(clubId)) {
            case Some(club) => club.clubName
            case None => "未知社团"
        }
    }
}
