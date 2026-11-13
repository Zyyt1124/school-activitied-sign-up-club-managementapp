import { promptAction, router } from '@kit.ArkUI';
import { AppColors, AppSpace, AppText } from '../common/constants/AppTheme';
import { ApiClient, ApiError } from '../common/api/ApiClient';
import {
  ActivityDetail,
  ActivityDetailParams,
  ActivityState,
  EmptyBody,
  SignUpReceipt
} from '../common/models';
import { formatDateTime } from '../common/utils/DateFormat';
import { StateTag } from '../components/StateTag';

@Entry
@Component
struct ActivityDetailPage {
  @State title: string = '';
  @State clubName: string = '';
  @State description: string = '';
  @State location: string = '';
  @State state: ActivityState = ActivityState.OPEN;
  @State remainCount: number = 0;
  @State maxCount: number = 0;
  @State signStart: number = 0;
  @State signEnd: number = 0;
  @State activityTime: number = 0;
  @State signed: boolean = false;
  @State loaded: boolean = false;
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State errorMessage: string = '';

  private activityId: number = 0;
  private idempotencyKey: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as ActivityDetailParams;
    if (params === null || params === undefined || params.activityId === undefined) {
      this.errorMessage = '活动参数缺失';
      this.loading = false;
      return;
    }
    this.activityId = params.activityId;
    this.idempotencyKey = `sign-${this.activityId}-${Date.now()}`;
    this.loadDetail();
  }

  private async loadDetail(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      const detail = await ApiClient.get<ActivityDetail>(`/activities/${this.activityId}`);
      this.title = detail.title;
      this.clubName = detail.clubName;
      this.description = detail.description;
      this.location = detail.location;
      this.state = detail.state;
      this.remainCount = detail.remainCount;
      this.maxCount = detail.maxCount;
      this.signStart = detail.signStart;
      this.signEnd = detail.signEnd;
      this.activityTime = detail.activityTime;
      this.signed = detail.signed;
      this.loaded = true;
    } catch (error) {
      const apiError = error as ApiError;
      this.errorMessage = apiError.message !== undefined ? apiError.message : '活动加载失败';
    } finally {
      this.loading = false;
    }
  }

  private canSign(): boolean {
    return this.state === ActivityState.OPEN && this.remainCount > 0 && !this.signed;
  }

  private async signUp(): Promise<void> {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    try {
      const body = new EmptyBody();
      const receipt = await ApiClient.post<SignUpReceipt>(
        `/activities/${this.activityId}/sign-ups`,
        body,
        this.idempotencyKey
      );
      this.signed = true;
      this.remainCount = receipt.remainCount;
      promptAction.showToast({ message: '报名成功' });
    } catch (error) {
      const apiError = error as ApiError;
      if (apiError.code === 'ALREADY_SIGNED') {
        this.signed = true;
      }
      promptAction.showToast({ message: apiError.message !== undefined ? apiError.message : '报名失败' });
    } finally {
      this.submitting = false;
    }
  }

  private async cancelSignUp(): Promise<void> {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    try {
      const receipt = await ApiClient.del<SignUpReceipt>(`/activities/${this.activityId}/sign-ups`);
      this.signed = false;
      this.remainCount = receipt.remainCount;
      promptAction.showToast({ message: '已取消报名' });
    } catch (error) {
      const apiError = error as ApiError;
      promptAction.showToast({ message: apiError.message !== undefined ? apiError.message : '取消失败' });
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  infoRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(AppText.caption)
        .fontColor(AppColors.muted)
        .width(52)
      Text(value)
        .fontSize(AppText.body)
        .fontColor(AppColors.inkSecondary)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回')
          .fontSize(AppText.body)
          .fontColor(AppColors.blue)
          .onClick(() => {
            router.back();
          })
        Text('活动详情')
          .fontSize(AppText.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.ink)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text(' ')
          .fontSize(AppText.body)
          .width(48)
      }
      .width('100%')
      .height(48)
      .padding({ left: AppSpace.page, right: AppSpace.page })

      if (this.loading) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(AppColors.blue)
          Text('正在加载活动详情…')
            .fontSize(AppText.caption)
            .fontColor(AppColors.muted)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMessage.length > 0) {
        Column({ space: 12 }) {
          Text(this.errorMessage)
            .fontSize(AppText.body)
            .fontColor(AppColors.danger)
          Button('重试')
            .fontSize(AppText.caption)
            .fontColor(AppColors.white)
            .backgroundColor(AppColors.blue)
            .onClick(() => {
              this.loadDetail();
            })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.loaded) {
        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 10 }) {
              Row() {
                Text(this.title)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColors.ink)
                  .layoutWeight(1)
                StateTag({ state: this.state })
              }
              .width('100%')

              Text(this.clubName)
                .fontSize(AppText.caption)
                .fontColor(AppColors.blue)
                .width('100%')
            }
            .width('100%')
            .padding(AppSpace.card)
            .backgroundColor(AppColors.white)
            .borderRadius(AppSpace.radius)

            Column({ space: 12 }) {
              this.infoRow('时间', formatDateTime(this.activityTime))
              this.infoRow('地点', this.location)
              this.infoRow('报名', `${formatDateTime(this.signStart)} 至 ${formatDateTime(this.signEnd)}`)
              this.infoRow('名额', `${this.remainCount} / ${this.maxCount} 可报名`)
            }
            .width('100%')
            .padding(AppSpace.card)
            .backgroundColor(AppColors.white)
            .borderRadius(AppSpace.radius)

            Column({ space: 8 }) {
              Text('活动简介')
                .fontSize(AppText.section)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.ink)
                .width('100%')
              Text(this.description.length > 0 ? this.description : '负责人还没有填写活动简介。')
                .fontSize(AppText.body)
                .fontColor(AppColors.inkSecondary)
                .lineHeight(22)
                .width('100%')
            }
            .width('100%')
            .padding(AppSpace.card)
            .backgroundColor(AppColors.white)
            .borderRadius(AppSpace.radius)
            .alignItems(HorizontalAlign.Start)
          }
          .padding({ left: AppSpace.page, right: AppSpace.page, bottom: 24 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Text('剩余名额')
              .fontSize(11)
              .fontColor(AppColors.muted)
            Text(`${this.remainCount}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.remainCount > 0 ? AppColors.orange : AppColors.muted)
          }
          .alignItems(HorizontalAlign.Start)

          Button(this.signed ? '取消报名' : (this.submitting ? '提交中…' : '立即报名'))
            .layoutWeight(1)
            .height(48)
            .fontSize(AppText.body)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.signed ? AppColors.danger : AppColors.white)
            .backgroundColor(this.signed ? AppColors.white : (this.canSign() ? AppColors.blue : AppColors.muted))
            .borderRadius(10)
            .enabled(!this.submitting && (this.signed || this.canSign()))
            .onClick(() => {
              if (this.signed) {
                this.cancelSignUp();
              } else {
                this.signUp();
              }
            })
        }
        .width('100%')
        .padding({ left: AppSpace.page, right: AppSpace.page, top: 10, bottom: 18 })
        .backgroundColor(AppColors.white)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.bg)
  }
}
