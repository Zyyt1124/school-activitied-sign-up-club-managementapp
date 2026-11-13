import { router } from '@kit.ArkUI';
import { AppColors, AppSpace, AppText } from '../common/constants/AppTheme';
import { ApiClient, ApiError } from '../common/api/ApiClient';
import { SessionStore } from '../common/auth/SessionStore';
import { ActivityDetailParams, ActivitySummary, PageResult, Role } from '../common/models';
import { ActivityCard } from '../components/ActivityCard';
import { EmptyState } from '../components/EmptyState';

@Entry
@Component
struct Main {
  @State selectedTab: number = 0;
  @State activities: ActivitySummary[] = [];
  @State loading: boolean = false;
  @State errorMessage: string = '';
  @State userName: string = '';
  @State userRole: string = '';
  @State college: string = '';

  aboutToAppear(): void {
    this.loadUser();
    this.loadActivities();
  }

  private async loadUser(): Promise<void> {
    const session = await SessionStore.load();
    if (session === null) {
      router.replaceUrl({ url: 'pages/Login' });
      return;
    }
    this.userName = session.user.name;
    this.college = session.user.college;
    this.userRole = this.roleLabel(session.user.role);
  }

  private roleLabel(role: Role): string {
    switch (role) {
      case Role.CLUB_LEADER:
        return '社团负责人';
      case Role.ADMIN:
        return '学校管理员';
      default:
        return '学生';
    }
  }

  private async loadActivities(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const page = await ApiClient.get<PageResult<ActivitySummary>>('/activities?state=open');
      this.activities = page.items;
    } catch (error) {
      const apiError = error as ApiError;
      this.errorMessage = apiError.message !== undefined ? apiError.message : '活动加载失败';
    } finally {
      this.loading = false;
    }
  }

  private openDetail(activity: ActivitySummary): void {
    const params: ActivityDetailParams = { activityId: activity.activityId };
    router.pushUrl({ url: 'pages/ActivityDetail', params: params });
  }

  private async logout(): Promise<void> {
    await SessionStore.clear();
    ApiClient.clearToken();
    router.replaceUrl({ url: 'pages/Login' });
  }

  @Builder
  tabBuilder(title: string, index: number) {
    Column({ space: 3 }) {
      Text(title)
        .fontSize(11)
        .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.selectedTab === index ? AppColors.blue : AppColors.muted)
      Divider()
        .width(18)
        .strokeWidth(2)
        .color(this.selectedTab === index ? AppColors.blue : Color.Transparent)
    }
    .width('100%')
    .height(52)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  activityTab() {
    Column() {
      Row() {
        Column({ space: 3 }) {
          Text('发现活动')
            .fontSize(AppText.pageTitle)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.ink)
          Text('报名状态、名额、时间都在这里对齐')
            .fontSize(AppText.caption)
            .fontColor(AppColors.muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('刷新')
          .fontSize(AppText.caption)
          .fontColor(AppColors.blue)
          .backgroundColor(AppColors.white)
          .height(32)
          .onClick(() => {
            this.loadActivities();
          })
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      if (this.loading) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(AppColors.blue)
          Text('正在加载活动…')
            .fontSize(AppText.caption)
            .fontColor(AppColors.muted)
        }
        .width('100%')
        .padding({ top: 48 })
      } else if (this.errorMessage.length > 0) {
        Column({ space: 12 }) {
          Text(this.errorMessage)
            .fontSize(AppText.body)
            .fontColor(AppColors.danger)
            .textAlign(TextAlign.Center)
          Button('重试')
            .fontSize(AppText.caption)
            .fontColor(AppColors.white)
            .backgroundColor(AppColors.blue)
            .onClick(() => {
              this.loadActivities();
            })
        }
        .width('100%')
        .padding({ top: 48 })
      } else if (this.activities.length === 0) {
        EmptyState({ title: '暂时没有可报名的活动', hint: '等社团负责人发布后，这里会自动出现。' })
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.activities, (item: ActivitySummary) => {
              ActivityCard({
                activity: item,
                onTap: () => {
                  this.openDetail(item);
                }
              })
            }, (item: ActivitySummary) => `${item.activityId}`)
          }
          .padding({ bottom: 24 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppSpace.page, right: AppSpace.page })
  }

  @Builder
  clubTab() {
    Column() {
      Text('社团')
        .fontSize(AppText.pageTitle)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.ink)
        .width('100%')
        .padding({ top: 12, bottom: 8 })
      EmptyState({
        title: '社团主页正在搭建',
        hint: '社团列表、入社申请、成员管理会复用同一套角色权限。'
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppSpace.page, right: AppSpace.page })
  }

  @Builder
  myTab() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Text(this.userName.length > 0 ? this.userName : '未登录')
          .fontSize(AppText.pageTitle)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.ink)
          .width('100%')
        Text(`${this.userRole} · ${this.college}`)
          .fontSize(AppText.caption)
          .fontColor(AppColors.muted)
          .width('100%')
      }
      .width('100%')
      .padding(AppSpace.card)
      .backgroundColor(AppColors.white)
      .borderRadius(AppSpace.radius)

      Column({ space: 12 }) {
        this.myRow('我的报名', '查看已报名的活动与签到状态')
        Divider().color(AppColors.line)
        this.myRow('我的社团', '入社申请与成员身份')
        Divider().color(AppColors.line)
        this.myRow('消息中心', '报名结果与活动提醒')
      }
      .width('100%')
      .padding(AppSpace.card)
      .backgroundColor(AppColors.white)
      .borderRadius(AppSpace.radius)

      Blank()

      Button('退出登录')
        .width('100%')
        .height(46)
        .fontSize(AppText.body)
        .fontColor(AppColors.danger)
        .backgroundColor(AppColors.white)
        .borderRadius(10)
        .onClick(() => {
          this.logout();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppSpace.page, right: AppSpace.page, top: 12, bottom: 24 })
  }

  @Builder
  myRow(title: string, hint: string) {
    Row() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(AppText.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.ink)
        Text(hint)
          .fontSize(AppText.caption)
          .fontColor(AppColors.muted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(20)
        .fontColor(AppColors.muted)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.selectedTab }) {
      TabContent() {
        this.activityTab()
      }
      .tabBar(this.tabBuilder('活动', 0))

      TabContent() {
        this.clubTab()
      }
      .tabBar(this.tabBuilder('社团', 1))

      TabContent() {
        this.myTab()
      }
      .tabBar(this.tabBuilder('我的', 2))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.bg)
    .barHeight(56)
    .barBackgroundColor(AppColors.white)
    .onChange((index: number) => {
      this.selectedTab = index;
    })
  }
}
