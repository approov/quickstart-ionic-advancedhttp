import { Component, OnInit } from '@angular/core';

// COMMENT THE LINE BELOW IF USING APPROOV
import { HTTP, HTTPResponse } from '@awesome-cordova-plugins/http/ngx';

// UNCOMMENT THE LINE BELOW IF USING APPROOV
//import { HTTP, HTTPResponse } from '@awesome-cordova-plugins/approov-advanced-http/ngx';

@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss'],
})
export class AppComponent implements OnInit {
  private http: HTTP = new HTTP();
  readonly imageBaseUrl = 'assets/';
  readonly imageExtension = 'png';
  readonly host = 'https://shapes.approov.io';

  // CHANGE TO v3 FOR APPROOV WITH API PROTECTION; USE v1 FOR APPROOV WITH SECRETS PROTECTION
  readonly VERSION: string = 'v1'; 

  readonly HELLO_URL = `${this.host}/v1/hello`;
  readonly SHAPE_URL = `${this.host}/${this.VERSION}/shapes`;

  // COMMENT IF USING APPROOV WITH SECRETS PROTECTION
  readonly API_KEY = `yXClypapWNHIifHUWmBIyPFAm`;

  // UNCOMMENT IF USING APPROOV WITH SECRETS PROTECTION
  //readonly API_KEY = `shapes_api_key_placeholder`;

  message = 'Tap Hello to Start...';
  imageUrl = this.getImageUrl('approov');
  isLoading = false;

  ngOnInit(): void {
    // UNCOMMENT IF USING APPROOV
    //this.http.approovInitialize("<enter-your-config-string-here>");

    // UNCOMMENT IF USING APPROOV SECRETS PROTECTION
    //this.http.approovAddSubstitutionHeader("Api-Key", "");
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
      const response = await this.http.get(this.SHAPE_URL, {}, {'Api-Key': this.API_KEY});
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
  }
}
