package campus.service

import std.collection.*
import campus.domain.*
import campus.repository.*

/**
 * 报名核心业务。
 *
 * 关键点不是「查一下还有没有名额」，而是：
 *  1. 整个「校验 -> 扣名额 -> 写报名记录 -> 写消息」在一个事务边界内；
 *  2. 名额扣减由仓储层的原子操作完成，服务层不先查后改（避免 TOCTOU）；
 *  3. 写操作带幂等键，网络重试不会产生重复报名。
 */
public class SignUpService {
    private let activities: ActivityRepository
    private let signs: SignRepository
    private let messages: MessageRepository
    private let tx: TxRunner
    private let clock: Clock

    public init(
        activities: ActivityRepository,
        signs: SignRepository,
        messages: MessageRepository,
        tx: TxRunner,
        clock: Clock
    ) {
        this.activities = activities
        this.signs = signs
        this.messages = messages
        this.tx = tx
        this.clock = clock
    }

    public func signUp(
        actor: Actor,
        activityId: Int64,
        idempotencyKey: String
    ): Outcome<SignUpReceipt, BizError> {
        return tx.run<Outcome<SignUpReceipt, BizError>>({ =>
            match (activities.find(activityId)) {
                case None => fail<SignUpReceipt>(notFoundError("ACTIVITY_NOT_FOUND", "活动不存在"))
                case Some(activity) =>
                    let now = clock.nowMillis()
                    if (!inSignWindow(activity, now)) {
                        return fail<SignUpReceipt>(conflictError("NOT_IN_SIGN_PERIOD", "当前不在报名时间内"))
                    }

                    // 先查幂等键：同一个请求的重试必须返回第一次的结果，
                    // 不能被下面的「已报名」判断误伤。
                    if (idempotencyKey.size > 0) {
                        match (signs.findByIdempotencyKey(idempotencyKey)) {
                            case Some(existing) =>
                                if (existing.userId != actor.userId || existing.activityId != activityId) {
                                    return fail<SignUpReceipt>(
                                        conflictError("IDEMPOTENCY_KEY_REUSED", "请求标识已被其他操作使用")
                                    )
                                }
                                if (existing.cancelled) {
                                    return fail<SignUpReceipt>(
                                        conflictError("IDEMPOTENCY_KEY_REUSED", "该请求对应的报名已取消，请重新发起")
                                    )
                                }
                                return succeed<SignUpReceipt>(SignUpReceipt(
                                    existing.signId,
                                    activityId,
                                    actor.userId,
                                    existing.signTime,
                                    activity.remainCount
                                ))
                            case None => ()
                        }
                    }

                    match (signs.findActive(activityId, actor.userId)) {
                        case Some(_) =>
                            return fail<SignUpReceipt>(conflictError("ALREADY_SIGNED", "您已报名该活动，不可重复报名"))
                        case None => ()
                    }

                    if (!activities.tryReserveSeat(activityId)) {
                        return fail<SignUpReceipt>(conflictError("NO_SEAT", "名额已满，报名失败"))
                    }

                    let record = signs.create(activityId, actor.userId, now, idempotencyKey)
                    let remainCount = match (activities.find(activityId)) {
                        case Some(updated) => updated.remainCount
                        case None => 0
                    }
                    messages.create(
                        actor.userId,
                        "报名成功",
                        "活动【${activity.title}】报名成功，请按时参加。",
                        "signup",
                        now
                    )
                    succeed<SignUpReceipt>(SignUpReceipt(record.signId, activityId, actor.userId, now, remainCount))
            }
        })
    }

    public func cancel(actor: Actor, activityId: Int64): Outcome<SignUpReceipt, BizError> {
        return tx.run<Outcome<SignUpReceipt, BizError>>({ =>
            match (activities.find(activityId)) {
                case None => fail<SignUpReceipt>(notFoundError("ACTIVITY_NOT_FOUND", "活动不存在"))
                case Some(activity) =>
                    let now = clock.nowMillis()
                    if (now > activity.signEnd) {
                        return fail<SignUpReceipt>(conflictError("CANCEL_CLOSED", "报名已截止，不能取消"))
                    }

                    match (signs.findActive(activityId, actor.userId)) {
                        case Some(record) =>
                            signs.cancel(record.signId)
                            activities.releaseSeat(activityId)
                            let remainCount = match (activities.find(activityId)) {
                                case Some(updated) => updated.remainCount
                                case None => 0
                            }
                            messages.create(
                                actor.userId,
                                "取消报名",
                                "活动【${activity.title}】的报名已取消，名额已归还。",
                                "cancel",
                                now
                            )
                            succeed<SignUpReceipt>(SignUpReceipt(
                                record.signId,
                                activityId,
                                actor.userId,
                                now,
                                remainCount
                            ))
                        case None =>
                            // 已取消过：返回成功，保证取消操作幂等。
                            match (signs.findLatest(activityId, actor.userId)) {
                                case Some(latest) =>
                                    if (latest.cancelled) {
                                        return succeed<SignUpReceipt>(SignUpReceipt(
                                            latest.signId,
                                            activityId,
                                            actor.userId,
                                            latest.signTime,
                                            activity.remainCount
                                        ))
                                    }
                                    return fail<SignUpReceipt>(conflictError("NOT_SIGNED", "您尚未报名该活动"))
                                case None =>
                                    return fail<SignUpReceipt>(conflictError("NOT_SIGNED", "您尚未报名该活动"))
                            }
                    }
            }
        })
    }

    public func listSignUps(actor: Actor, activityId: Int64): Outcome<ArrayList<SignRecord>, BizError> {
        match (activities.find(activityId)) {
            case None => fail<ArrayList<SignRecord>>(notFoundError("ACTIVITY_NOT_FOUND", "活动不存在"))
            case Some(activity) =>
                match (requireClubManager(actor, activity.clubId)) {
                    case Some(error) => fail<ArrayList<SignRecord>>(error)
                    case None => succeed<ArrayList<SignRecord>>(signs.listByActivity(activityId))
                }
        }
    }
}
