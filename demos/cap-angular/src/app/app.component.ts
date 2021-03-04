import { Component } from '@angular/core';
import { HTTP, HTTPResponse } from '@ionic-native/http/ngx';

@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss'],
})
export class AppComponent {
  private http: HTTP = new HTTP();
  readonly imageBaseUrl = 'assets/';
  readonly imageExtension = 'png';
  readonly VERSION = 'v2'; // Change To v2 when using Approov
  readonly HELLO_URL = `https://shapes.approov.io/v1/hello`;
  readonly SHAPE_URL = `https://shapes.approov.io/${this.VERSION}/shapes`;
  message = 'Tap Hello to Start...';
  imageUrl = this.getImageUrl('approov');
  isLoading = false;

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
  }

  getImageUrl(name: string): string {
    return `${this.imageBaseUrl}${name}.${this.imageExtension}`;
  }

  private onAPIError(err: HTTPResponse) {
    this.hideLoadingIndicator();
    const error = JSON.parse(err.error);
    this.message = `Status Code: ${err.status}, ${error.status}`;
    this.imageUrl = this.getImageUrl('confused');
  }

  private presentLoadingIndicator() {
    this.isLoading = true;
    this.imageUrl = this.getImageUrl('approov');
    this.message = 'Fetching Data.....';
  }

  private hideLoadingIndicator() {
    this.isLoading = false;
  }
}
