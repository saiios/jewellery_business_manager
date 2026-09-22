import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://esm.sh/jose@6.0.11";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-notification-admin-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type FirebaseServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

type CustomerToken = {
  id: string;
  token: string;
};

function jsonResponse(
  body: unknown,
  status = 200,
) {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

async function getFirebaseAccessToken(
  serviceAccount: FirebaseServiceAccount,
): Promise<string> {
  const tokenUri = serviceAccount.token_uri ??
    "https://oauth2.googleapis.com/token";

  const now = Math.floor(Date.now() / 1000);

  const privateKey = await importPKCS8(
    serviceAccount.private_key,
    "RS256",
  );

  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({
      alg: "RS256",
      typ: "JWT",
    })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience(tokenUri)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const response = await fetch(tokenUri, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  const responseText = await response.text();

  if (!response.ok) {
    throw new Error(
      `Unable to obtain Firebase access token: ${responseText}`,
    );
  }

  const tokenData = JSON.parse(responseText);

  if (!tokenData.access_token) {
    throw new Error(
      "Firebase access token was not returned.",
    );
  }

  return tokenData.access_token;
}

async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  deviceToken: string,
  title: string,
  message: string,
  productId: string,
  itemCode: string,
) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,

          notification: {
            title,
            body: message,
          },

          data: {
            type: "product",
            product_id: productId,
            item_code: itemCode,
          },

          android: {
            priority: "high",
            notification: {
              channel_id: "devi_jewels_default",
              sound: "default",
            },
          },
        },
      }),
    },
  );

  const responseText = await response.text();

  let responseBody: unknown = null;

  try {
    responseBody = responseText ? JSON.parse(responseText) : null;
  } catch (_) {
    responseBody = responseText;
  }

  return {
    ok: response.ok,
    status: response.status,
    body: responseBody,
  };
}

function isInvalidTokenResponse(
  result: {
    status: number;
    body: unknown;
  },
): boolean {
  if (
    result.status === 404 ||
    result.status === 410
  ) {
    return true;
  }

  if (
    typeof result.body === "object" &&
    result.body !== null
  ) {
    const body = result.body as {
      error?: {
        details?: Array<{
          errorCode?: string;
        }>;
      };
    };

    const details = body.error?.details ?? [];

    return details.some(
      (detail) =>
        detail.errorCode ===
          "UNREGISTERED" ||
        detail.errorCode ===
          "INVALID_ARGUMENT",
    );
  }

  return false;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return jsonResponse(
      {
        error: "Method not allowed.",
      },
      405,
    );
  }

  try {
    // ----------------------------------------------------------
    // 1. Check the Admin notification key.
    // ----------------------------------------------------------

    const configuredAdminKey = Deno.env.get(
      "NOTIFICATION_ADMIN_KEY",
    );

    if (!configuredAdminKey) {
      throw new Error(
        "NOTIFICATION_ADMIN_KEY is not configured.",
      );
    }

    const suppliedAdminKey = req.headers.get(
      "x-notification-admin-key",
    );

    if (
      !suppliedAdminKey ||
      suppliedAdminKey !== configuredAdminKey
    ) {
      return jsonResponse(
        {
          error: "Unauthorized.",
        },
        401,
      );
    }

    // ----------------------------------------------------------
    // 2. Parse request.
    // ----------------------------------------------------------

    const body = await req.json();

    const productId = body?.product_id?.toString().trim() ?? "";

    const itemCode = body?.item_code?.toString().trim() ?? "";

    const title = body?.title?.toString().trim() ?? "";

    const message = body?.message?.toString().trim() ?? "";

    if (!productId) {
      return jsonResponse(
        {
          error: "product_id is required.",
        },
        400,
      );
    }

    if (!itemCode) {
      return jsonResponse(
        {
          error: "item_code is required.",
        },
        400,
      );
    }

    if (!title) {
      return jsonResponse(
        {
          error: "title is required.",
        },
        400,
      );
    }

    if (!message) {
      return jsonResponse(
        {
          error: "message is required.",
        },
        400,
      );
    }

    // ----------------------------------------------------------
    // 3. Supabase admin client.
    // ----------------------------------------------------------

    const supabaseUrl = Deno.env.get("SUPABASE_URL");

    const serviceRoleKey = Deno.env.get(
      "SUPABASE_SERVICE_ROLE_KEY",
    );

    if (
      !supabaseUrl ||
      !serviceRoleKey
    ) {
      throw new Error(
        "Supabase server configuration is missing.",
      );
    }

    const supabaseAdmin = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );

    // ----------------------------------------------------------
    // 4. Verify that the product still exists.
    // ----------------------------------------------------------

    const {
      data: product,
      error: productError,
    } = await supabaseAdmin
      .from("products")
      .select(
        "id, item_code, product_name, selling_price, mrp, quantity, status",
      )
      .eq("id", productId)
      .maybeSingle();

    if (productError) {
      throw productError;
    }

    if (!product) {
      return jsonResponse(
        {
          error: "Product not found.",
        },
        404,
      );
    }

    // ----------------------------------------------------------
    // 5. Get active Android customer tokens.
    // ----------------------------------------------------------

    const {
      data: tokens,
      error: tokensError,
    } = await supabaseAdmin
      .from("customer_push_tokens")
      .select("id, token")
      .eq("is_active", true)
      .eq("platform", "android");

    if (tokensError) {
      throw tokensError;
    }

    const customerTokens = (tokens ?? []) as CustomerToken[];

    // ----------------------------------------------------------
    // 6. Create notification history record.
    // ----------------------------------------------------------

    const {
      data: notification,
      error: notificationError,
    } = await supabaseAdmin
      .from("customer_notifications")
      .insert({
        product_id: product.id,
        item_code: product.item_code ?? itemCode,
        title,
        message,
        recipient_count: customerTokens.length,
        status: customerTokens.length > 0 ? "sending" : "sent",
        sent_at: customerTokens.length > 0 ? null : new Date().toISOString(),
      })
      .select("id")
      .single();

    if (notificationError) {
      throw notificationError;
    }

    // ----------------------------------------------------------
    // 7. No registered customers yet.
    // ----------------------------------------------------------

    if (customerTokens.length === 0) {
      return jsonResponse({
        success: true,
        notification_id: notification.id,
        recipient_count: 0,
        success_count: 0,
        failed_count: 0,
        message:
          "Notification saved, but no active Android customer tokens were found.",
      });
    }

    // ----------------------------------------------------------
    // 8. Get Firebase OAuth access token.
    // ----------------------------------------------------------

    const firebaseJson = Deno.env.get(
      "FIREBASE_SERVICE_ACCOUNT_JSON",
    );

    if (!firebaseJson) {
      throw new Error(
        "FIREBASE_SERVICE_ACCOUNT_JSON is not configured.",
      );
    }

    const serviceAccount = JSON.parse(
      firebaseJson,
    ) as FirebaseServiceAccount;

    if (
      !serviceAccount.project_id ||
      !serviceAccount.client_email ||
      !serviceAccount.private_key
    ) {
      throw new Error(
        "Firebase service-account JSON is incomplete.",
      );
    }

    const accessToken = await getFirebaseAccessToken(
      serviceAccount,
    );

    // ----------------------------------------------------------
    // 9. Send to each active customer token.
    // ----------------------------------------------------------

    let successCount = 0;
    let failedCount = 0;

    const invalidTokenIds: string[] = [];

    for (const customerToken of customerTokens) {
      try {
        const result = await sendFcmMessage(
          accessToken,
          serviceAccount.project_id,
          customerToken.token,
          title,
          message,
          product.id,
          product.item_code ??
            itemCode,
        );

        if (result.ok) {
          successCount++;
        } else {
          failedCount++;

          if (
            isInvalidTokenResponse(
              result,
            )
          ) {
            invalidTokenIds.push(
              customerToken.id,
            );
          }

          console.error(
            "FCM send failed:",
            {
              tokenId: customerToken.id,
              status: result.status,
              body: result.body,
            },
          );
        }
      } catch (error) {
        failedCount++;

        console.error(
          "FCM send exception:",
          error,
        );
      }
    }

    // ----------------------------------------------------------
    // 10. Deactivate invalid tokens.
    // ----------------------------------------------------------

    if (invalidTokenIds.length > 0) {
      const {
        error: deactivateError,
      } = await supabaseAdmin
        .from("customer_push_tokens")
        .update({
          is_active: false,
          updated_at: new Date().toISOString(),
        })
        .in(
          "id",
          invalidTokenIds,
        );

      if (deactivateError) {
        console.error(
          "Unable to deactivate invalid tokens:",
          deactivateError,
        );
      }
    }

    // ----------------------------------------------------------
    // 11. Update notification history.
    // ----------------------------------------------------------

    let finalStatus:
      | "sent"
      | "partial"
      | "failed";

    if (
      successCount > 0 &&
      failedCount === 0
    ) {
      finalStatus = "sent";
    } else if (
      successCount > 0 &&
      failedCount > 0
    ) {
      finalStatus = "partial";
    } else {
      finalStatus = "failed";
    }

    const {
      error: updateError,
    } = await supabaseAdmin
      .from("customer_notifications")
      .update({
        recipient_count: customerTokens.length,
        status: finalStatus,
        sent_at: new Date().toISOString(),
      })
      .eq(
        "id",
        notification.id,
      );

    if (updateError) {
      console.error(
        "Unable to update notification history:",
        updateError,
      );
    }

    return jsonResponse({
      success: successCount > 0,
      notification_id: notification.id,
      recipient_count: customerTokens.length,
      success_count: successCount,
      failed_count: failedCount,
      invalid_token_count: invalidTokenIds.length,
      status: finalStatus,
    });
  } catch (error) {
    console.error(
      "send-product-notification error:",
      error,
    );

    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Unable to send notification.",
      },
      500,
    );
  }
});
