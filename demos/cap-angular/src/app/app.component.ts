import { Component, OnInit } from '@angular/core';
import { ApproovHttp, HTTPResponse } from '@ionic-native/approov-advanced-http/ngx';
import { ApproovLoggableToken } from '@ionic-native/approov-advanced-http';

@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss'],
})
export class AppComponent implements OnInit {
  private http: ApproovHttp = new ApproovHttp();
  readonly imageBaseUrl = 'assets/';
  readonly imageExtension = 'png';
  readonly host = 'https://shapes.approov.io';
  readonly VERSION = 'v2'; // Change To v2 when using Approov
  readonly HELLO_URL = `${this.host}/v1/hello`;
  readonly SHAPE_URL = `${this.host}/${this.VERSION}/shapes`;
  message = 'Tap Hello to Start...';
  imageUrl = this.getImageUrl('approov');
  isLoading = false;
  loggableToken: ApproovLoggableToken;

  ngOnInit(): void {
    if (this.isApproov()) {
      this.http.initializeApproov();
    }
  }

  async onHelloClick() {
    this.presentLoadingIndicator();
    try {
      const response = await this.http.get(this.HELLO_URL, {}, {});
      this.hideLoadingIndicator();
      const data = JSON.parse(response.data);
      this.message = data.text;
      this.imageUrl = this.getImageUrl('hello');
    } catch (err) {
      this.onAPIError(err);
    }
  }

  async onShapeClick() {
    this.presentLoadingIndicator();
    try {
      const response = await this.http.get(this.SHAPE_URL, {}, {});
      this.hideLoadingIndicator();
      const data = JSON.parse(response.data);
      this.message = data.status;
      this.imageUrl = this.getImageUrl(data.shape.toLowerCase());
    } catch (err) {
      this.onAPIError(err);
    }

    if (this.isApproov()) {
      this.loggableToken = await this.http.getApproovLoggableToken(this.host);
    }
  }

  getImageUrl(name: string): string {
    return `${this.imageBaseUrl}${name}.${this.imageExtension}`;
  }

  private onAPIError(err: HTTPResponse) {
    this.hideLoadingIndicator();
    try {
      const error = JSON.parse(err.error);
      this.message = `Status Code: ${err.status}, ${error.status}`;
    } catch {
      this.message = `Status Code: ${err.status}, ${err.error}`;
    }
    this.imageUrl = this.getImageUrl('confused');
  }

  private presentLoadingIndicator() {
    this.isLoading = true;
    this.imageUrl = this.getImageUrl('approov');
    this.message = 'Fetching Data.....';
  }

  private hideLoadingIndicator() {
    this.isLoading = false;
    this.loggableToken = undefined;
  }

  private isApproov(): boolean {
    return this.VERSION === 'v2';
  }
}
