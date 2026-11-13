package campus.service

import std.collection.*
import campus.domain.*
import campus.repository.*

/**
 * 活动发布与状态流转。
 *
 * 状态机逻辑单独放在 domain/state_machine.cj，service 只负责：
 *  - 鉴权（谁能操作这个社团）
 *  - 参数校验
 *  - 在事务边界内落库
 */
public class ActivityService {
    private let clubs: ClubRepository
    private let activities: ActivityRepository
    private let tx: TxRunner
    private let clock: Clock

    public init(
        clubs: ClubRepository,
        activities: ActivityRepository,
        tx: TxRunner,
        clock: Clock
    ) {
        this.clubs = clubs
        this.activities = activities
        this.tx = tx
        this.clock = clock
    }

    public func createDraft(
        actor: Actor,
        clubId: Int64,
        title: String,
        description: String,
        location: String,
        maxCount: Int64,
        signStart: Int64,
        signEnd: Int64,
        activityTime: Int64
    ): Outcome<Activity, BizError> {
        return tx.run<Outcome<Activity, BizError>>({ =>
            if (title.size == 0) {
                return fail<Activity>(invalidError("INVALID_TITLE", "活动名称不能为空"))
            }
            if (maxCount <= 0) {
                return fail<Activity>(invalidError("INVALID_MAX_COUNT", "活动名额必须大于 0"))
            }
            if (signStart >= signEnd) {
                return fail<Activity>(invalidError("INVALID_SIGN_PERIOD", "报名开始时间必须早于截止时间"))
            }
            if (signEnd > activityTime) {
                return fail<Activity>(invalidError("INVALID_ACTIVITY_TIME", "活动时间不能早于报名截止时间"))
            }

            match (clubs.find(clubId)) {
                case None => fail<Activity>(notFoundError("CLUB_NOT_FOUND", "社团不存在"))
                case Some(_) =>
                    match (requireClubManager(actor, clubId)) {
                        case Some(error) => fail<Activity>(error)
                        case None =>
                            let activity = activities.create(
                                clubId,
                                title,
                                description,
                                location,
                                maxCount,
                                signStart,
                                signEnd,
                                activityTime,
                                Draft
                            )
                            succeed<Activity>(activity)
                    }
            }
        })
    }

    public func publish(actor: Actor, activityId: Int64): Outcome<Activity, BizError> {
        return transition(actor, activityId, Open)
    }

    public func close(actor: Actor, activityId: Int64): Outcome<Activity, BizError> {
        return transition(actor, activityId, Closed)
    }

    public func archive(actor: Actor, activityId: Int64): Outcome<Activity, BizError> {
        return transition(actor, activityId, Archived)
    }

    public func disable(actor: Actor, activityId: Int64): Outcome<Activity, BizError> {
        return tx.run<Outcome<Activity, BizError>>({ =>
            match (requireAdmin(actor)) {
                case Some(error) => return fail<Activity>(error)
                case None => ()
            }
            match (activities.find(activityId)) {
                case None => fail<Activity>(notFoundError("ACTIVITY_NOT_FOUND", "活动不存在"))
                case Some(activity) =>
                    if (!canTransition(activity.state, Disabled)) {
                        return fail<Activity>(conflictError("INVALID_STATE_TRANSITION", "当前状态不能下架"))
                    }
                    activity.state = Disabled
                    activities.save(activity)
                    succeed<Activity>(activity)
            }
        })
    }

    private func transition(actor: Actor, activityId: Int64, target: ActivityState): Outcome<Activity, BizError> {
        return tx.run<Outcome<Activity, BizError>>({ =>
            match (activities.find(activityId)) {
                case None => fail<Activity>(notFoundError("ACTIVITY_NOT_FOUND", "活动不存在"))
                case Some(activity) =>
                    match (requireClubManager(actor, activity.clubId)) {
                        case Some(error) => return fail<Activity>(error)
                        case None => ()
                    }
                    if (!canTransition(activity.state, target)) {
                        return fail<Activity>(conflictError("INVALID_STATE_TRANSITION", "当前状态不能执行该操作"))
                    }
                    activity.state = target
                    activities.save(activity)
                    succeed<Activity>(activity)
            }
        })
    }

    public func find(activityId: Int64): Option<Activity> {
        return activities.find(activityId)
    }

    public func listOpen(): ArrayList<Activity> {
        let result = ArrayList<Activity>()
        for (activity in activities.list()) {
            if (isOpenState(activity.state)) {
                result.add(activity)
            }
        }
        return result
    }

    public func listByClub(clubId: Int64): ArrayList<Activity> {
        let result = ArrayList<Activity>()
        for (activity in activities.list()) {
            if (activity.clubId == clubId) {
                result.add(activity)
            }
        }
        return result
    }
}
