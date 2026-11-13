package campus.domain

/**
 * 活动状态机。
 *
 * 草稿 -> 报名中 -> 报名结束 -> 已结束
 * 任意未结束状态 -> 已下架（管理员）
 *
 * 用封闭 enum + 穷举 match，新增状态时编译器会提醒补分支，
 * 避免 ArkTS 里常见的字符串状态越写越多、漏判断。
 */
public func canTransition(from: ActivityState, to: ActivityState): Bool {
    match ((from, to)) {
        case (Draft, Open) => true
        case (Open, Closed) => true
        case (Closed, Archived) => true
        case (Draft, Disabled) => true
        case (Open, Disabled) => true
        case (Closed, Disabled) => true
        case (Draft, Archived) => true
        case _ => false
    }
}

public func isOpenState(state: ActivityState): Bool {
    match (state) {
        case Open => true
        case Draft | Closed | Archived | Disabled => false
    }
}

public func isArchivedState(state: ActivityState): Bool {
    match (state) {
        case Archived | Disabled => true
        case Draft | Open | Closed => false
    }
}

public func activityStateValue(state: ActivityState): String {
    match (state) {
        case Draft => "draft"
        case Open => "open"
        case Closed => "closed"
        case Archived => "archived"
        case Disabled => "disabled"
    }
}

public func roleValue(role: Role): String {
    match (role) {
        case Student => "student"
        case ClubLeader => "club_leader"
        case Admin => "admin"
    }
}

public func clubStatusValue(status: ClubStatus): String {
    match (status) {
        case Pending => "pending"
        case Active => "active"
        case Disabled => "disabled"
    }
}

/**
 * 报名是否处于可操作窗口。
 * 名额是否充足由仓储层的原子扣减决定，不在这里判断，避免 TOCTOU。
 */
public func inSignWindow(activity: Activity, nowMillis: Int64): Bool {
    return isOpenState(activity.state) && nowMillis >= activity.signStart && nowMillis <= activity.signEnd
}
